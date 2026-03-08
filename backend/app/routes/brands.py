# app/routes/brands.py
# Brand API endpoints for the Swipify ecommerce platform.
# Handles fetching all brands and a single brand with its associated products.

from fastapi import APIRouter, HTTPException
from firebase_client import db

router = APIRouter()


@router.get("")
async def get_brands():
    """Fetch all brands from Firebase Firestore."""
    try:
        docs = db.collection("brands").get()
        brands = []
        for doc in docs:
            brand = doc.to_dict()
            brand["id"] = doc.id
            brands.append(brand)
        return {"brands": brands}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{brand_id}")
async def get_brand(brand_id: str):
    """Fetch a single brand by ID, along with all products that belong to it.
    
    Returns brand info + a list of matching products.
    Used by the dynamic brand detail page in Flutter.
    """
    try:
        # Fetch brand document
        brand_doc = db.collection("brands").document(brand_id).get()
        if not brand_doc.exists:
            raise HTTPException(status_code=404, detail="Brand not found")

        brand = brand_doc.to_dict()
        brand["id"] = brand_doc.id

        # Fetch products that belong to this brand
        product_docs = (
            db.collection("products")
            .where("brandId", "==", brand_id)
            .get()
        )
        products = []
        for doc in product_docs:
            product = doc.to_dict()
            product["id"] = doc.id
            products.append(product)

        return {"brand": brand, "products": products}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
