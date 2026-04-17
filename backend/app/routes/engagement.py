from fastapi import APIRouter, HTTPException
from firebase_client import db
from app.models.engagement import LikeRequest, RecentlyViewedRequest
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from datetime import datetime

router = APIRouter()

# --- LIKES ---

@router.post("/like")
async def like_product(request: LikeRequest):
    try:
        like_id = f"{request.user_id}_{request.product_id}"
        db.collection("likes").document(like_id).set({
            "user_id": request.user_id,
            "product_id": request.product_id,
            "created_at": SERVER_TIMESTAMP
        })
        return {"status": "ok", "message": "Product liked"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/unlike")
async def unlike_product(user_id: str, product_id: str):
    try:
        like_id = f"{user_id}_{product_id}"
        db.collection("likes").document(like_id).delete()
        return {"status": "ok", "message": "Product unliked"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/likes/{user_id}")
async def get_user_likes(user_id: str):
    """Fetches full product details for liked items."""
    try:
        docs = db.collection("likes").where("user_id", "==", user_id).get()
        product_ids = [doc.to_dict().get("product_id") for doc in docs]
        
        products = []
        if product_ids:
            # Firestore 'in' query supports up to 10-30 elements depending on version, 
            # for Swipify we'll assume a reasonable default.
            # In production, this would be chunked.
            product_docs = db.collection("products").where("id", "in", product_ids).get()
            for doc in product_docs:
                products.append(doc.to_dict())
                
        return {"liked_products": products}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- RECENTLY VIEWED ---

@router.post("/viewed")
async def log_viewed_product(request: RecentlyViewedRequest):
    try:
        view_id = f"{request.user_id}_{request.product_id}"
        db.collection("recently_viewed").document(view_id).set({
            "user_id": request.user_id,
            "product_id": request.product_id,
            "timestamp": SERVER_TIMESTAMP
        })
        
        # Trim logic
        views = db.collection("recently_viewed").where("user_id", "==", request.user_id).order_by("timestamp", direction="DESCENDING").get()
        if len(views) > 30:
            for old_view in views[30:]:
                old_view.reference.delete()
        
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/viewed/{user_id}")
async def get_recently_viewed(user_id: str):
    """Fetches full product details for recently viewed items."""
    try:
        docs = db.collection("recently_viewed").where("user_id", "==", user_id).order_by("timestamp", direction="DESCENDING").get()
        product_ids = [doc.to_dict().get("product_id") for doc in docs]
        
        products_map = {}
        if product_ids:
            product_docs = db.collection("products").where("id", "in", product_ids[:10]).get()
            for doc in product_docs:
                data = doc.to_dict()
                products_map[data["id"]] = data
                
        # Return in original order
        results = []
        for pid in product_ids[:10]:
            if pid in products_map:
                results.append(products_map[pid])
                
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
