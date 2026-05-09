from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List
from firebase_client import db
from app.models.review import ReviewCreateRequest, ReviewResponse
from app.utils.auth_utils import get_current_user, verify_owner
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from google.cloud import firestore
from datetime import datetime
import uuid

router = APIRouter()

@router.post("", response_model=ReviewResponse)
async def create_review(request: ReviewCreateRequest, token: dict = Depends(get_current_user)):
    """Submit a review for a product."""
    try:
        # [SECURITY FIX] Verify the user ID in request matches the authenticated token
        verify_owner(request.user_id, token["uid"])

        # Check if order exists and is delivered/completed
        order_doc = db.collection("orders").document(request.order_id).get()
        if not order_doc.exists:
            raise HTTPException(status_code=404, detail="Order not found")
        
        # Verify user ID matches order (additional check)
        order_data = order_doc.to_dict()
        if order_data.get("user_id") != request.user_id:
            raise HTTPException(status_code=403, detail="Unauthorized: Order does not belong to user")
            
        # Check if already reviewed (one review per product per order)
        existing = db.collection("reviews").where("order_id", "==", request.order_id).where("product_id", "==", request.product_id).get()
        if len(existing) > 0:
            raise HTTPException(status_code=400, detail="Product already reviewed for this order")

        review_id = str(uuid.uuid4())
        
        # Fetch user name for display (denormalized for fast reads)
        user_doc = db.collection("users").document(request.user_id).get()
        # [AUTH FIX] Corrected 'full_name' -> 'name' or 'display_name'
        user_info = user_doc.to_dict() if user_doc.exists else {}
        user_name = user_info.get("name", user_info.get("display_name", "Anonymous"))

        review_data = {
            "id": review_id,
            "user_id": request.user_id,
            "user_name": user_name,
            "product_id": request.product_id,
            "order_id": request.order_id,
            "rating": request.rating,
            "comment": request.comment,
            "image_urls": request.image_urls,
            "created_at": datetime.now().isoformat(), # Default for response
        }
        
        # Save to DB with server timestamp
        db_data = review_data.copy()
        db_data["created_at"] = SERVER_TIMESTAMP
        db.collection("reviews").document(review_id).set(db_data)
        
        # [PERFORMANCE FIX] Update product average_rating + total_reviews atomically
        _update_product_rating_atomic(request.product_id, request.rating)

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
        # Try ordered query first (requires composite index)
        try:
            query = (
                db.collection("reviews")
                .where("product_id", "==", product_id)
                .order_by("created_at", direction=firestore.Query.DESCENDING)
            )
            # Use offset/limit properly if possible, but slicing is safer for fallback logic
            docs = list(query.get())
        except Exception as idx_err:
            print(f"[REVIEWS] Ordered query failed ({idx_err}), falling back to unordered")
            docs = list(
                db.collection("reviews")
                .where("product_id", "==", product_id)
                .get()
            )
            def _sort_key(doc):
                ca = doc.to_dict().get("created_at")
                if hasattr(ca, "timestamp"): return ca.timestamp()
                if isinstance(ca, str):
                    try: return datetime.fromisoformat(ca).timestamp()
                    except: return 0
                return 0
            docs.sort(key=_sort_key, reverse=True)

        docs = docs[offset:offset + limit]

        results = []
        for doc in docs:
            data = doc.to_dict()
            if hasattr(data.get("created_at"), "isoformat"):
                data["created_at"] = data["created_at"].isoformat()
            else:
                data["created_at"] = str(data.get("created_at"))
            results.append(data)

        return results
    except Exception as e:
        print(f"[REVIEW FETCH ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))


def _update_product_rating_atomic(product_id: str, new_rating: int):
    """Update average_rating + total_reviews atomically using a transaction. O(1) performance."""
    transaction = db.transaction()
    product_ref = db.collection("products").document(product_id)

    @firestore.transactional
    def update_in_transaction(transaction, product_ref):
        snapshot = product_ref.get(transaction=transaction)
        if not snapshot.exists:
            return
        
        data = snapshot.to_dict()
        old_avg = data.get("average_rating", 0.0)
        old_count = data.get("total_reviews", 0)
        
        new_count = old_count + 1
        # Formula for running average: ((prev_avg * prev_count) + new_val) / new_count
        new_avg = ((old_avg * old_count) + new_rating) / new_count
        
        transaction.update(product_ref, {
            "average_rating": round(new_avg, 2),
            "total_reviews": new_count
        })

    try:
        update_in_transaction(transaction, product_ref)
        print(f"[RATING ATOMIC] Successfully updated product {product_id}")
    except Exception as e:
        print(f"[RATING ATOMIC ERROR] {e}")
