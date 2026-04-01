from fastapi import APIRouter, HTTPException, Query
from firebase_client import db
from typing import List

router = APIRouter()

@router.get("")
async def get_brands():
    """Fetch all brands from Firebase Firestore."""
    try:
        # ── Fetch Brands from Firebase ───────────────────
        docs = db.collection("brands").get()
        brands = []
        for doc in docs:
            brand = doc.to_dict()
            brand["id"] = doc.id
            brands.append(brand)
        
        # If empty, return fallback for first run
        if not brands:
            return {"brands": [
                {
                    "id": "nike", 
                    "name": "Nike", 
                    "icon": "sports_baseball",
                    "tagline": "Just Do It",
                    "description": "Leading sports brand worldwide.",
                    "logoUrl": "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=100&q=80",
                    "bannerUrl": "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800&q=80"
                },
                {
                    "id": "samsung", 
                    "name": "Samsung", 
                    "icon": "smartphone",
                    "tagline": "Join the Flip Side",
                    "description": "Innovative electronics and mobile devices.",
                    "logoUrl": "https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=100&q=80",
                    "bannerUrl": "https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=800&q=80"
                },
                {
                    "id": "apple", 
                    "name": "Apple", 
                    "icon": "laptop_mac",
                    "tagline": "Think Different",
                    "description": "Premium consumer electronics and software.",
                    "logoUrl": "https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=100&q=80",
                    "bannerUrl": "https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=800&q=80"
                },
                {
                    "id": "adidas", 
                    "name": "Adidas", 
                    "icon": "run_circle",
                    "tagline": "Impossible is Nothing",
                    "description": "Performance and style for every athlete.",
                    "logoUrl": "https://images.unsplash.com/photo-1587563871167-1ee9c731aefb?w=100&q=80",
                    "bannerUrl": "https://images.unsplash.com/photo-1587563871167-1ee9c731aefb?w=800&q=80"
                },
                {
                    "id": "sony", 
                    "name": "Sony", 
                    "icon": "tv",
                    "tagline": "Be Moved",
                    "description": "Creative entertainment and cutting-edge tech.",
                    "logoUrl": "https://images.unsplash.com/photo-1607853202273-797f1c22a38e?w=100&q=80",
                    "bannerUrl": "https://images.unsplash.com/photo-1607853202273-797f1c22a38e?w=800&q=80"
                },
                {
                    "id": "logitech", 
                    "name": "Logitech", 
                    "icon": "mouse",
                    "tagline": "Defy Logic",
                    "description": "Premium peripherals for work and play.",
                    "logoUrl": "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=100&q=80",
                    "bannerUrl": "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=800&q=80"
                },
            ]}
            
        print(f"[HOME] Streamed {len(brands)} brands for buyer UI.")
        return {"brands": brands}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
