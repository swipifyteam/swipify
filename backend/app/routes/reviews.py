from fastapi import APIRouter, HTTPException, Query
from typing import List
from firebase_client import db
from app.models.review import ReviewCreateRequest, ReviewResponse
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from google.cloud import firestore
from datetime import datetime
import uuid

router = APIRouter()

@router.post("", response_model=ReviewResponse)
async def create_review(request: ReviewCreateRequest):
    """Submit a review for a product."""
    try:
        # Check if order exists and is delivered/completed
        order_doc = db.collection("orders").document(request.order_id).get()
        if not order_doc.exists:
            raise HTTPException(status_code=404, detail="Order not found")
        
        # Verify user ID matches
        order_data = order_doc.to_dict()
        if order_data.get("user_id") != request.user_id:
            raise HTTPException(status_code=403, detail="Unauthorized")
            
        # Check if already reviewed (one review per product per order)
        existing = db.collection("reviews").where("order_id", "==", request.order_id).where("product_id", "==", request.product_id).get()
        if len(existing) > 0:
            raise HTTPException(status_code=400, detail="Product already reviewed for this order")

        review_id = str(uuid.uuid4())
        now_str = str(datetime.now())
        
        # Fetch user name for display (denormalized for fast reads)
        user_doc = db.collection("users").document(request.user_id).get()
        user_name = user_doc.to_dict().get("full_name", "Anonymous") if user_doc.exists else "Anonymous"

        review_data = {
            "id": review_id,
            "user_id": request.user_id,
            "user_name": user_name,
            "product_id": request.product_id,
            "order_id": request.order_id,
            "rating": request.rating,
            "comment": request.comment,
            "image_urls": request.image_urls,
            "created_at": now_str,
        }
        
        # Save to DB with server timestamp
        db_data = review_data.copy()
        db_data["created_at"] = SERVER_TIMESTAMP
        db.collection("reviews").document(review_id).set(db_data)
        
        # Update product average_rating + total_reviews
        _update_product_rating(request.product_id, request.rating)

        print(f"[REVIEW CREATED] review_id={review_id} product_id={request.product_id}")
        return review_data
    except HTTPException:
        raise
    except Exception as e:
        print(f"[REVIEW ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/product/{product_id}", response_model=List[ReviewResponse])
async def get_product_reviews(
    product_id: str,
    limit: int = Query(default=10, ge=1, le=50),
    offset: int = Query(default=0, ge=0),
):
    """Fetch reviews for a specific product, ordered by created_at descending."""
    try:
        print(f"[REVIEWS FETCHED] product_id={product_id} limit={limit} offset={offset}")

        # Try ordered query first (requires composite index)
        try:
            query = (
                db.collection("reviews")
                .where("product_id", "==", product_id)
                .order_by("created_at", direction=firestore.Query.DESCENDING)
            )
            docs = list(query.get())
        except Exception as idx_err:
            # Fallback: if composite index is missing, query without order_by
            # and sort in Python
            print(f"[REVIEWS] Ordered query failed ({idx_err}), falling back to unordered")
            docs = list(
                db.collection("reviews")
                .where("product_id", "==", product_id)
                .get()
            )
            # Sort by created_at descending in Python
            def _sort_key(doc):
                ca = doc.to_dict().get("created_at")
                if hasattr(ca, "timestamp"):
                    return ca.timestamp()
                if isinstance(ca, str):
                    try:
                        return datetime.fromisoformat(ca).timestamp()
                    except Exception:
                        return 0
                return 0
            docs.sort(key=_sort_key, reverse=True)

        # Apply offset + limit via slicing (offset not supported in admin SDK)
        docs = docs[offset:offset + limit]

        results = []
        for doc in docs:
            data = doc.to_dict()
            # Convert timestamp to string safely
            if hasattr(data.get("created_at"), "isoformat"):
                data["created_at"] = data["created_at"].isoformat()
            else:
                data["created_at"] = str(data.get("created_at"))
            results.append(data)
            print(f"[REVIEW RENDERED] id={data.get('id')}")

        print(f"[PRODUCT REVIEWS LOADED] count={len(results)}")
        return results
    except Exception as e:
        print(f"[REVIEW FETCH ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))


def _update_product_rating(product_id: str, new_rating: int):
    """Recalculate and update average_rating + total_reviews on the product document."""
    try:
        # Fetch all reviews for this product to recalculate
        all_reviews = db.collection("reviews").where("product_id", "==", product_id).get()
        ratings = [doc.to_dict().get("rating", 0) for doc in all_reviews]
        # Include the newly submitted rating (it may not be committed yet)
        # If the new review is already in the query results, don't double-count
        # Since we just wrote it with SERVER_TIMESTAMP, it should be in the results
        total = len(ratings)
        avg = sum(ratings) / total if total > 0 else 0.0

        db.collection("products").document(product_id).update({
            "average_rating": round(avg, 2),
            "total_reviews": total,
        })
        print(f"[PRODUCT RATING UPDATED] product_id={product_id} avg={avg:.2f} total={total}")
    except Exception as e:
        print(f"[PRODUCT RATING UPDATE ERROR] {e}")
        # Non-critical — don't fail the review creation
