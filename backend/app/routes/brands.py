# app/routes/brands.py
# Brand endpoints for the Swipify ecommerce platform.
# Handles fetching all brands and fetching a single brand with its products.

from fastapi import APIRouter, HTTPException
from firebase_client import db

router = APIRouter()

# ── Fallback brands used when Firestore has no brand documents ────────────────
FALLBACK_BRANDS = {
    "nike": {
        "id": "nike", "name": "Nike", "icon": "sports_baseball",
        "tagline": "Just Do It", "description": "Leading sports brand worldwide.",
        "logoUrl": "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=100&q=80",
        "bannerUrl": "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800&q=80",
    },
    "samsung": {
        "id": "samsung", "name": "Samsung", "icon": "smartphone",
        "tagline": "Join the Flip Side", "description": "Innovative electronics and mobile devices.",
        "logoUrl": "https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=100&q=80",
        "bannerUrl": "https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=800&q=80",
    },
    "apple": {
        "id": "apple", "name": "Apple", "icon": "laptop_mac",
        "tagline": "Think Different", "description": "Premium consumer electronics and software.",
        "logoUrl": "https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=100&q=80",
        "bannerUrl": "https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=800&q=80",
    },
    "adidas": {
        "id": "adidas", "name": "Adidas", "icon": "run_circle",
        "tagline": "Impossible is Nothing", "description": "Performance and style for every athlete.",
        "logoUrl": "https://images.unsplash.com/photo-1587563871167-1ee9c731aefb?w=100&q=80",
        "bannerUrl": "https://images.unsplash.com/photo-1587563871167-1ee9c731aefb?w=800&q=80",
    },
    "sony": {
        "id": "sony", "name": "Sony", "icon": "tv",
        "tagline": "Be Moved", "description": "Creative entertainment and cutting-edge tech.",
        "logoUrl": "https://images.unsplash.com/photo-1607853202273-797f1c22a38e?w=100&q=80",
        "bannerUrl": "https://images.unsplash.com/photo-1607853202273-797f1c22a38e?w=800&q=80",
    },
    "logitech": {
        "id": "logitech", "name": "Logitech", "icon": "mouse",
        "tagline": "Defy Logic", "description": "Premium peripherals for work and play.",
        "logoUrl": "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=100&q=80",
        "bannerUrl": "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=800&q=80",
    },
}


@router.get("")
async def get_brands():
    """Fetch all brands from Firebase Firestore. Falls back to static list if empty."""
    try:
        docs = db.collection("brands").get()
        brands = []
        for doc in docs:
            brand = doc.to_dict()
            brand["id"] = doc.id
            brands.append(brand)

        if not brands:
            print("[BRANDS] No brands in Firestore — returning fallback list.")
            return {"brands": list(FALLBACK_BRANDS.values())}

        print(f"[BRANDS] Returning {len(brands)} brands from Firestore.")
        return {"brands": brands}
    except Exception as e:
        print(f"[BRANDS ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{brand_id}")
async def get_brand_with_products(brand_id: str):
    """Fetch a single brand and all its published products."""
    try:
        # 1. Try to get brand from Firestore
        brand_doc = db.collection("brands").document(brand_id).get()

        if brand_doc.exists:
            brand = brand_doc.to_dict()
            brand["id"] = brand_doc.id
        elif brand_id in FALLBACK_BRANDS:
            brand = dict(FALLBACK_BRANDS[brand_id])
        else:
            print(f"[BRAND NOT FOUND] brand_id={brand_id}")
            raise HTTPException(status_code=404, detail="Brand not found")

        print(f"[BRAND FILTER] Fetching products for brand: {brand.get('name')} (id={brand_id})")

        # 2. Try querying by brandId field first, fallback to brand field
        docs = db.collection("products").where("brandId", "==", brand_id).where("is_published", "==", True).get()
        products = []
        for doc in docs:
            product = doc.to_dict()
            product["id"] = doc.id
            products.append(product)

        # If no products found via brandId, try legacy "brand" field
        if not products:
            docs_legacy = db.collection("products").where("brand", "==", brand_id).where("is_published", "==", True).get()
            for doc in docs_legacy:
                product = doc.to_dict()
                product["id"] = doc.id
                products.append(product)

        print(f"[BRAND FILTER] Found {len(products)} products for brand: {brand.get('name')}")
        return {"brand": brand, "products": products}

    except HTTPException:
        raise
    except Exception as e:
        print(f"[BRAND ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))
