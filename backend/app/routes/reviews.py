from fastapi import APIRouter, HTTPException
from typing import List
from firebase_client import db
from app.models.review import ReviewCreateRequest, ReviewResponse
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
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
            
        # Check if already reviewed (optional: allow multiple? usually one per product per order)
        existing = db.collection("reviews").where("order_id", "==", request.order_id).where("product_id", "==", request.product_id).get()
        if len(existing) > 0:
            raise HTTPException(status_code=400, detail="Product already reviewed for this order")

        review_id = str(uuid.uuid4())
        now = SERVER_TIMESTAMP
        
        # Fetch user name for display
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
            "created_at": str(datetime.now()) # Server timestamp is better but for Pydantic response we use string
        }
        
        # Save to DB (actually using server timestamp in DB)
        db_data = review_data.copy()
        db_data["created_at"] = now
        db.collection("reviews").document(review_id).set(db_data)
        
        # Update product average rating? (Advanced)
        # For now, just return
        review_data["created_at"] = str(datetime.now())
        return review_data
    except HTTPException:
        raise
    except Exception as e:
        print(f"[REVIEW ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/product/{product_id}", response_model=List[ReviewResponse])
async def get_product_reviews(product_id: str):
    """Fetch all reviews for a specific product."""
    try:
        docs = db.collection("reviews").where("product_id", "==", product_id).get()
        results = []
        for doc in docs:
            data = doc.to_dict()
            # Convert timestamp to string
            if hasattr(data.get("created_at"), "isoformat"):
                data["created_at"] = data["created_at"].isoformat()
            else:
                data["created_at"] = str(data.get("created_at"))
            results.append(data)
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

from datetime import datetime
