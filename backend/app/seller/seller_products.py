from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from app.utils.notifications import broadcast_notification
import uuid

router = APIRouter()

class ProductCreateRequest(BaseModel):
    sellerId: str
    name: str
    brandId: str
    price: float
    stock: int
    description: str
    images: List[str]
    sizes: Optional[List[str]] = None
    colors: Optional[List[str]] = None

class ProductUpdateRequest(BaseModel):
    name: Optional[str] = None
    brandId: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    description: Optional[str] = None
    images: Optional[List[str]] = None
    sizes: Optional[List[str]] = None
    colors: Optional[List[str]] = None

@router.get("/{seller_id}")
async def get_seller_products(seller_id: str):
    """Fetch all products belonging to a specific seller."""
    try:
        docs = db.collection("products").where("sellerId", "==", seller_id).get()
        products = []
        for doc in docs:
            product = doc.to_dict()
            product["id"] = doc.id
            products.append(product)
        return {"products": products}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("")
async def create_product(request: ProductCreateRequest):
    """Create a new product tied to a seller and their shop."""
    try:
        # ── RESOLVE IDENTITY ──────────────────────────────────────────────────
        uid = request.sellerId
        print(f"[AUTH] Resolving identity for: {uid}")

        user_doc_ref = db.collection("users").document(uid)
        user_doc = user_doc_ref.get()
        
        user_data = {}
        if user_doc.exists:
            user_data = user_doc.to_dict()
            print(f"[USER] Core profile found for {uid}")
        else:
            print(f"[USER] Profile missing for {uid}. Checking Seller records...")
            # Fallback: search sellers collection for this userId
            seller_docs = db.collection("sellers").where("userId", "==", uid).limit(1).get()
            if len(seller_docs) == 0:
                raise HTTPException(status_code=404, detail="User not found in system")
            
            seller_info = seller_docs[0].to_dict()
            seller_status = seller_info.get("status", "PENDING")
            
            if seller_status != "APPROVED":
                raise HTTPException(status_code=403, detail="User is not an approved seller")
            
            # AUTO-PROVISION USER DOCUMENT
            user_data = {
                "uid": uid,
                "role": "seller",
                "seller_status": "APPROVED",
                "storeName": seller_info.get("storeName", "My Shop"),
                "createdAt": SERVER_TIMESTAMP
            }
            user_doc_ref.set(user_data)
            print(f"[USER] Auto-provisioned missing user profile for {uid}")

        # ── VALIDATE PERMISSIONS ──────────────────────────────────────────────
        seller_status = user_data.get("seller_status", "PENDING")
        if seller_status != "APPROVED":
            print(f"[SELLER] Blocked: {uid} status is {seller_status}")
            raise HTTPException(status_code=403, detail="User is not an approved seller")

        # ── STEP 4 & 5: CHECK shop_id (CRITICAL) ──────────────────────────────
        shop_id = user_data.get("shop_id")
        print(f"[SHOP] shop_id from user doc: {shop_id}")

        shop_doc = None
        if shop_id:
            shop_doc = db.collection("shops").document(shop_id).get()

        # 🔥 AUTO-FIX (REQUIRED IF MISSING) ────────────────────────────────────
        if not shop_id or not shop_doc or not shop_doc.exists:
            print("[SHOP] ROOT CAUSE FOUND: Shop ID or document missing. Auto-fixing...")
            
            # Use UID as the shop ID for consistency if missing
            new_shop_id = shop_id or uid
            
            # Create Shop immediately
            shop_data = {
                "owner_id": uid,
                "shop_name": user_data.get("storeName") or "My Shop",
                "created_at": SERVER_TIMESTAMP,
                "is_active": True,
                "description": "Welcome to my shop!"
            }
            db.collection("shops").document(new_shop_id).set(shop_data)
            
            # Link User to Shop
            user_doc_ref.update({"shop_id": new_shop_id})
            
            shop_id = new_shop_id
            print(f"[SHOP] Shop auto-created and linked: {shop_id}")
        else:
            print(f"[SHOP] Shop document verified: {shop_id}")

        # ── STEP 6: CREATE PRODUCT (ONLY AFTER FIX) ───────────────────────────
        new_doc_ref = db.collection("products").document()
        product_data = request.model_dump()
        product_data["shopId"] = shop_id
        product_data["seller_id"] = uid # Ensure seller_id is added
        product_data["is_published"] = True
        product_data["createdAt"] = SERVER_TIMESTAMP
        product_data["rating"] = 0.0
        
        new_doc_ref.set(product_data)
        print(f"[PRODUCT] Product created successfully: {new_doc_ref.id}")

        # ── BROADCAST NOTIFICATION (Retention Core) ───────────────────────────
        broadcast_notification(
            title="New Product Available",
            message=f"{request.name} is now available!",
            notification_type="NEW_PRODUCT"
        )
        
        product_data["id"] = new_doc_ref.id
        # Remove Sentinel before returning JSON response
        product_data.pop("createdAt", None)
        
        return {"message": "Product created successfully", "product": product_data}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{product_id}")
async def update_product(product_id: str, request: ProductUpdateRequest):
    """Update an existing product."""
    try:
        doc_ref = db.collection("products").document(product_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Product not found")
            
        update_data = {k: v for k, v in request.model_dump().items() if v is not None}
        update_data["updatedAt"] = SERVER_TIMESTAMP
        doc_ref.update(update_data)
        
        return {"message": "Product updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{product_id}")
async def delete_product(product_id: str):
    """Delete a product."""
    try:
        db.collection("products").document(product_id).delete()
        return {"message": "Product deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
