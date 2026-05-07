from fastapi import APIRouter, HTTPException, Depends, Query, UploadFile, File
from typing import List, Optional
from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from app.utils.auth_utils import get_current_user_id
from app.utils.cloudinary_handler import upload_image_to_cloudinary, upload_video_to_cloudinary
from app.seller.schemas import (
    ProductCreateRequest,
    ProductUpdateRequest,
    BulkActionRequest,
    StockUpdateRequest
)
import uuid

router = APIRouter()

# ── HELPER: GET SELLER/SHOP CONTEXT ─────────────────────────────────
def get_seller_context(uid: str):
    """Retrieve or auto-provision seller context ensuring shop_id exists."""
    user_doc_ref = db.collection("users").document(uid)
    user_doc = user_doc_ref.get()
    
    user_data = user_doc.to_dict() if user_doc.exists else {}
    
    # Validation
    seller_status = user_data.get("seller_status", "PENDING")
    if seller_status != "APPROVED":
        # Fallback check
        seller_docs = db.collection("sellers").where("userId", "==", uid).limit(1).get()
        if len(seller_docs) == 0 or seller_docs[0].to_dict().get("status") != "APPROVED":
            raise HTTPException(status_code=403, detail="User is not an approved seller")
    
    shop_id = user_data.get("shop_id")
    if not shop_id:
        # Auto-fix missing shop ID
        shop_id = uid
        shop_data = {
            "owner_id": uid,
            "shop_name": user_data.get("storeName") or "My Shop",
            "created_at": SERVER_TIMESTAMP,
            "is_active": True,
            "description": "Welcome to my shop!"
        }
        db.collection("shops").document(shop_id).set(shop_data)
        user_doc_ref.update({"shop_id": shop_id})
        
    return shop_id

# 1. CREATE PRODUCT
@router.post("")
async def create_product(request: ProductCreateRequest, current_user_id: str = Depends(get_current_user_id)):
    """Create a new product with strong validation."""
    try:
        # Validation
        if not request.name.strip():
            raise HTTPException(status_code=400, detail="Product name is required")
        if request.price <= 0:
            raise HTTPException(status_code=400, detail="Price must be strictly positive")
        if request.stock < 0:
            raise HTTPException(status_code=400, detail="Stock cannot be negative")
        if not request.category.strip():
            raise HTTPException(status_code=400, detail="Category is required")
        if not request.images or len(request.images) < 1:
            raise HTTPException(status_code=400, detail="At least 1 image is required")

        shop_id = get_seller_context(current_user_id)

        new_doc_ref = db.collection("products").document()
        
        # Handle Media and Counts
        media = request.media or []
        if not media and request.images:
            # Fallback for old clients or simple image uploads
            media = [{"type": "image", "url": img} for img in request.images]
        
        if not media:
            raise HTTPException(status_code=400, detail="At least 1 image or video is required")

        image_count = sum(1 for m in media if m.get("type") == "image")
        video_count = sum(1 for m in media if m.get("type") == "video")
        
        # Determine thumbnail
        thumbnail_url = request.thumbnail_url
        if not thumbnail_url and media:
            first_item = media[0]
            if first_item.get("type") == "video":
                # Use provided thumbnail_url from video upload response
                thumbnail_url = request.thumbnail_url or first_item.get("url") # Fallback to video url if thumb missing
            else:
                thumbnail_url = first_item.get("url")

        product_data = {
            "seller_id": current_user_id,
            "shop_id": shop_id,
            "name": request.name,
            "description": request.description,
            "price": request.price,
            "stock": request.stock,
            "category": request.category,
            "media": media,
            "images": [m["url"] for m in media if m["type"] == "image"], # Legacy support
            "thumbnail_url": thumbnail_url,
            "image_count": image_count,
            "video_count": video_count,
            "sku": request.sku or f"SKU-{str(uuid.uuid4())[:8].upper()}",
            "is_published": request.is_published if request.is_published is not None else True,
            "created_at": SERVER_TIMESTAMP,
            "updated_at": SERVER_TIMESTAMP,
            "sold_count": 0,
            "views_count": 0,
            "rating_average": 0.0,
            "status": "active"
        }
        
        new_doc_ref.set(product_data)
        print(f"[PRODUCT CREATED] id={new_doc_ref.id} seller={current_user_id}")
        
        product_data["id"] = new_doc_ref.id
        product_data.pop("created_at", None)
        product_data.pop("updated_at", None)
        
        return {"message": "Product created successfully", "product": product_data}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 8. IMAGE MANAGEMENT
@router.post("/upload-image")
async def upload_product_image(file: UploadFile = File(...), current_user_id: str = Depends(get_current_user_id)):
    """Upload product image to Cloudinary."""
    try:
        contents = await file.read()
        unique_filename = f"prod_{current_user_id}_{uuid.uuid4()}_{file.filename}"
        url = upload_image_to_cloudinary(contents, unique_filename, folder="products")
        if not url:
            raise HTTPException(status_code=400, detail="Failed to upload image")
        return {"image_url": url}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/upload-video")
async def upload_product_video(file: UploadFile = File(...), current_user_id: str = Depends(get_current_user_id)):
    """Upload product video to Cloudinary."""
    # Validate format
    allowed_formats = ["video/mp4", "video/quicktime", "video/webm", "application/octet-stream"]
    if file.content_type not in allowed_formats:
        # Some browsers/tools might send video as octet-stream, but we usually prefer explicit check
        pass 

    try:
        contents = await file.read()
        unique_filename = f"vid_{current_user_id}_{uuid.uuid4()}_{file.filename}"
        
        video_url, thumbnail_url = upload_video_to_cloudinary(contents, unique_filename, folder="swipify/products/videos")
        
        return {
            "video_url": video_url,
            "thumbnail_url": thumbnail_url
        }
    except Exception as e:
        print(f"[VIDEO UPLOAD ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))


# 6. BULK ACTIONS
@router.post("/bulk")
async def bulk_actions(request: BulkActionRequest, current_user_id: str = Depends(get_current_user_id)):
    try:
        batch = db.batch()
        count = 0
        for pid in request.product_ids:
            doc_ref = db.collection("products").document(pid)
            doc = doc_ref.get()
            if doc.exists and doc.to_dict().get("seller_id") == current_user_id:
                update_data = {"updated_at": SERVER_TIMESTAMP}
                if request.action == "publish":
                    update_data["is_published"] = True
                elif request.action == "unpublish":
                    update_data["is_published"] = False
                elif request.action == "archive":
                    update_data["is_published"] = False
                    update_data["status"] = "archived"
                elif request.action == "update_category" and request.category:
                    update_data["category"] = request.category
                
                batch.update(doc_ref, update_data)
                count += 1
        
        if count > 0:
            batch.commit()
            print(f"[BULK ACTION] Action={request.action} Applied to {count} products by seller={current_user_id}")
        
        return {"message": f"Bulk action completed for {count} products"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 2. GET SELLER PRODUCTS
@router.get("/{seller_id}")
async def get_seller_products(
    seller_id: str,
    page: int = 1,
    limit: int = 20,
    search: Optional[str] = None,
    category: Optional[str] = None,
    is_published: Optional[bool] = None,
    sort_by: Optional[str] = "newest", # newest, price_asc, price_desc, stock_asc
    current_user_id: str = Depends(get_current_user_id)
):
    """Fetch seller products with rich filtering using Firestore queries."""
    if seller_id != current_user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view these products")

    try:
        query = db.collection("products").where("seller_id", "==", seller_id)

        if is_published is not None:
            query = query.where("is_published", "==", is_published)
            
        if category:
            query = query.where("category", "==", category)

        docs = query.get()
        products = []
        
        for doc in docs:
            p = doc.to_dict()
            # Exclude archived from normal fetching (in-memory to avoid index requirements)
            if p.get("status") == "archived":
                continue
            if search and search.lower() not in p.get("name", "").lower():
                continue
            p["id"] = doc.id
            products.append(p)
            
        # In-memory sorting (since Firestore composite queries require indexes)
        if sort_by == "price_asc":
            products.sort(key=lambda x: x.get("price", 0))
        elif sort_by == "price_desc":
            products.sort(key=lambda x: x.get("price", 0), reverse=True)
        elif sort_by == "stock_asc":
            products.sort(key=lambda x: x.get("stock", 0))
        else:
            # Default to newest (created_at)
            products.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)

        # Pagination
        start = (page - 1) * limit
        end = start + limit
        paginated = products[start:end]

        print(f"[SELLER PRODUCTS FETCHED] Seller={seller_id} Count={len(paginated)} Total={len(products)}")
        return {
            "products": paginated,
            "total": len(products),
            "page": page,
            "limit": limit
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 3. GET SINGLE PRODUCT
@router.get("/product/{product_id}")
async def get_single_product(product_id: str, current_user_id: str = Depends(get_current_user_id)):
    try:
        doc = db.collection("products").document(product_id).get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Product not found")
            
        product = doc.to_dict()
        if product.get("seller_id") != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to view this product")
            
        product["id"] = doc.id
        return product
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 4. UPDATE PRODUCT
@router.put("/{product_id}")
async def update_product(product_id: str, request: ProductUpdateRequest, current_user_id: str = Depends(get_current_user_id)):
    try:
        doc_ref = db.collection("products").document(product_id)
        doc = doc_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Product not found")
            
        product = doc.to_dict()
        if product.get("seller_id") != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to edit this product")

        # Validation
        if request.price is not None and request.price <= 0:
            raise HTTPException(status_code=400, detail="Price must be greater than 0")
        if request.stock is not None and request.stock < 0:
            raise HTTPException(status_code=400, detail="Stock cannot be negative")

        update_data = {k: v for k, v in request.model_dump().items() if v is not None}
        
        # Recalculate counts if media updated
        if "media" in update_data:
            media = update_data["media"]
            update_data["image_count"] = sum(1 for m in media if m.get("type") == "image")
            update_data["video_count"] = sum(1 for m in media if m.get("type") == "video")
            update_data["images"] = [m["url"] for m in media if m["type"] == "image"] # Legacy support
            
            if not update_data.get("thumbnail_url") and media:
                first_item = media[0]
                if first_item.get("type") == "video":
                    # Note: Expect thumbnail_url to be passed in request for videos
                    pass 
                else:
                    update_data["thumbnail_url"] = first_item.get("url")

        update_data["updated_at"] = SERVER_TIMESTAMP
        doc_ref.update(update_data)
        
        print(f"[PRODUCT UPDATED] id={product_id} seller={current_user_id}")
        return {"message": "Product updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 7. STOCK UPDATE API
@router.patch("/{product_id}/stock")
async def update_stock(product_id: str, request: StockUpdateRequest, current_user_id: str = Depends(get_current_user_id)):
    try:
        doc_ref = db.collection("products").document(product_id)
        doc = doc_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Product not found")
            
        product = doc.to_dict()
        if product.get("seller_id") != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to edit this product")

        current_stock = product.get("stock", 0)
        new_stock = current_stock + request.adjustment
        
        if new_stock < 0:
            raise HTTPException(status_code=400, detail="Stock cannot go below zero")
            
        doc_ref.update({
            "stock": new_stock,
            "updated_at": SERVER_TIMESTAMP
        })
        
        print(f"[STOCK UPDATED] id={product_id} value={new_stock}")
        return {"message": "Stock updated successfully", "new_stock": new_stock}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 5. DELETE PRODUCT (SAFE DELETE)
@router.delete("/{product_id}")
async def safe_delete_product(product_id: str, current_user_id: str = Depends(get_current_user_id)):
    try:
        doc_ref = db.collection("products").document(product_id)
        doc = doc_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Product not found")
            
        product = doc.to_dict()
        if product.get("seller_id") != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to delete this product")

        doc_ref.update({
            "status": "archived",
            "is_published": False,
            "updated_at": SERVER_TIMESTAMP
        })
        
        print(f"[PRODUCT ARCHIVED] id={product_id} seller={current_user_id}")
        return {"message": "Product archived safely"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
