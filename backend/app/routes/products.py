# app/routes/products.py
# Product API endpoints for the Swipify ecommerce platform.
# Handles fetching all products, a single product by ID, and searching by name.

from fastapi import APIRouter, HTTPException, Query
from firebase_client import db

router = APIRouter()


@router.get("")
async def get_products():
    """Fetch all products from Firebase Firestore."""
    try:
        docs = db.collection("products").get()
        products = []
        for doc in docs:
            product = doc.to_dict()
            product["id"] = doc.id
            products.append(product)
        return {"products": products}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/search")
async def search_products(q: str = Query(..., description="Search query for product name")):
    """Search products by name (case-insensitive prefix search).
    
    Example: GET /products/search?q=air
    Returns all products whose name starts with 'air' (case-insensitive).
    """
    try:
        q_lower = q.lower()
        docs = db.collection("products").get()
        results = []
        for doc in docs:
            product = doc.to_dict()
            product["id"] = doc.id
            # Filter: check if query appears anywhere in the product name
            if q_lower in product.get("name", "").lower():
                results.append(product)
        return {"products": results, "query": q}
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
        return product
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
