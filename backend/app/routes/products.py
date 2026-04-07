# app/routes/products.py
# Product API endpoints for the Swipify ecommerce platform.
# Handles fetching all products, a single product by ID, and searching by name.

from fastapi import APIRouter, HTTPException, Query
from firebase_client import db

router = APIRouter()


@router.get("")
async def get_products():
    """Fetch all published products from Firebase Firestore."""
    try:
        # ── ONLY STREAM PUBLISHED PRODUCTS (STRICT) ──────────────────────────
        docs = db.collection("products").where("is_published", "==", True).get()
        products = []
        shop_cache = {}
        for doc in docs:
            product = doc.to_dict()
            product["id"] = doc.id
            
            # Fetch shop name for display
            shop_id = product.get("shopId")
            if shop_id:
                if shop_id not in shop_cache:
                    shop_doc = db.collection("shops").document(shop_id).get()
                    if shop_doc.exists:
                        shop_cache[shop_id] = shop_doc.to_dict().get("shop_name", "Unknown Shop")
                    else:
                        shop_cache[shop_id] = "Unknown Shop"
                product["shopName"] = shop_cache[shop_id]
            
            products.append(product)
        print(f"[HOME] Streamed {len(products)} published products with shop info to frontend.")
        return {"products": products}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search")
async def search_products(q: str = Query(..., description="Search query for product name")):
    """Search published products by name (case-insensitive prefix search)."""
    try:
        q_lower = q.lower()
        # ── ONLY SEARCH PUBLISHED PRODUCTS ─────────────────────────────────
        docs = db.collection("products").where("is_published", "==", True).get()
        results = []
        shop_cache = {}
        for doc in docs:
            product = doc.to_dict()
            product["id"] = doc.id
            if q_lower in product.get("name", "").lower():
                # Fetch shop name for display
                shop_id = product.get("shopId")
                if shop_id:
                    if shop_id not in shop_cache:
                        shop_doc = db.collection("shops").document(shop_id).get()
                        if shop_doc.exists:
                            shop_cache[shop_id] = shop_doc.to_dict().get("shop_name", "Unknown Shop")
                        else:
                            shop_cache[shop_id] = "Unknown Shop"
                    product["shopName"] = shop_cache[shop_id]
                results.append(product)
        print(f"[PRODUCT] Search for '{q}' returned {len(results)} items.")
        return {"products": results, "query": q}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(0))


@router.get("/category/{category}")
async def get_products_by_category(category: str):
    """Fetch all products where category matches."""
    try:
        category_lower = category.lower()
        docs = db.collection("products").where("is_published", "==", True).get()
        results = []
        shop_cache = {}
        for doc in docs:
            product = doc.to_dict()
            product["id"] = doc.id
            if product.get("category", "").lower() == category_lower:
                # Fetch shop name for display
                shop_id = product.get("shopId")
                if shop_id:
                    if shop_id not in shop_cache:
                        shop_doc = db.collection("shops").document(shop_id).get()
                        if shop_doc.exists:
                            shop_cache[shop_id] = shop_doc.to_dict().get("shop_name", "Unknown Shop")
                        else:
                            shop_cache[shop_id] = "Unknown Shop"
                    product["shopName"] = shop_cache[shop_id]
                results.append(product)
        print(f"[CATEGORY FETCH] Fetched {len(results)} items for category '{category}'.")
        return {"products": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/seller/{seller_id}")
async def get_products_by_seller(seller_id: str):
    """Return all published products of that seller."""
    try:
        docs = db.collection("products").where("is_published", "==", True).get()
        results = []
        shop_cache = {}
        for doc in docs:
            product = doc.to_dict()
            product["id"] = doc.id
            doc_seller = product.get("seller_id") or product.get("sellerId")
            if doc_seller == seller_id:
                shop_id = product.get("shopId")
                if shop_id:
                    if shop_id not in shop_cache:
                        shop_doc = db.collection("shops").document(shop_id).get()
                        if shop_doc.exists:
                            shop_cache[shop_id] = shop_doc.to_dict().get("shop_name", "Unknown Shop")
                        else:
                            shop_cache[shop_id] = "Unknown Shop"
                    product["shopName"] = shop_cache[shop_id]
                results.append(product)
        print(f"[SELLER PRODUCTS FETCH] Fetched {len(results)} items for seller '{seller_id}'.")
        return {"products": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{product_id}")
async def get_product(product_id: str):
    """Fetch a single product by its Firestore document ID."""
    try:
        doc = db.collection("products").document(product_id).get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Product not found")
        product = doc.to_dict()
        product["id"] = doc.id
        
        # Fetch shop name
        shop_id = product.get("shopId")
        if shop_id:
            shop_doc = db.collection("shops").document(shop_id).get()
            if shop_doc.exists:
                product["shopName"] = shop_doc.to_dict().get("shop_name", "Unknown Shop")
            else:
                product["shopName"] = "Unknown Shop"
                
        return product
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
