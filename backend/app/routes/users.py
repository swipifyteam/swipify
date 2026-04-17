from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from firebase_client import db
from app.models.user import UserProfile, UserUpdateRequest
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
import cloudinary
import cloudinary.uploader
import os
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

# Cloudinary Configuration
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

router = APIRouter()

@router.get("/{uid}", response_model=UserProfile)
async def get_user_profile(uid: str):
    """Retrieve user profile from Firestore."""
    try:
        print(f"[USER FETCHED] UID: {uid}")
        doc = db.collection("users").document(uid).get()
        if not doc.exists:
            # Create a default user document if it doesn't exist
            # This is helpful for first-time login
            user_data = {
                "id": uid,
                "name": "New User",
                "email": f"{uid}@placeholder.com", 
                "role": "buyer",
                "created_at": SERVER_TIMESTAMP,
                "updated_at": SERVER_TIMESTAMP
            }
            db.collection("users").document(uid).set(user_data)
            # Fetch again to get the data
            doc = db.collection("users").document(uid).get()
        
        data = doc.to_dict()
        # Handle timestamp conversion
        for key in ["created_at", "updated_at"]:
            if data.get(key) and hasattr(data[key], "isoformat"):
                data[key] = data[key].isoformat()
        
        return data
    except Exception as e:
        print(f"[USER ERROR] Fetch failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/{uid}")
async def update_user(uid: str, request: UserUpdateRequest):
    """Update user name or role."""
    try:
        update_data = request.dict(exclude_none=True)
        if not update_data:
            return {"status": "no_change", "message": "Nothing to update"}
        
        update_data["updated_at"] = SERVER_TIMESTAMP
        db.collection("users").document(uid).update(update_data)
        
        print(f"[USER UPDATED] UID: {uid}, Data: {update_data}")
        return {"status": "ok", "message": "Profile updated"}
    except Exception as e:
        print(f"[USER ERROR] Update failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{uid}/orders")
async def get_user_orders(uid: str):
    """Fetch all orders for a specific user."""
    try:
        docs = db.collection("orders").where("user_id", "==", uid).get()
        orders = []
        for doc in docs:
            data = doc.to_dict()
            orders.append({
                "id": data.get("id"),
                "status": data.get("status"),
                "total_price": (data.get("total_price") or 0.0),
                "created_at": str(data.get("created_at"))
            })
        return orders
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/upload-profile-picture")
async def upload_profile_picture(user_id: str = Form(...), file: UploadFile = File(...)):
    """Uploads a profile picture to Cloudinary and updates Firestore."""
    try:
        # 1. Validation
        if not file.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="Invalid file type. Only images are allowed.")
        
        # Check size (5MB limit)
        contents = await file.read()
        if len(contents) > 5 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File too large. Max 5MB.")
        
        # 2. Upload to Cloudinary
        upload_result = cloudinary.uploader.upload(
            contents,
            folder="swipify/profile_pictures",
            public_id=f"profile_{user_id}",
            overwrite=True
        )
        
        image_url = upload_result.get("secure_url")
        
        # 3. Update Firestore
        db.collection("users").document(user_id).update({
            "profile_image": image_url,
            "updated_at": SERVER_TIMESTAMP
        })
        
        print(f"[PROFILE IMAGE UPLOADED] {image_url}")
        return {"profile_image": image_url}
        
    except Exception as e:
        print(f"[UPLOAD ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{uid}/reviews")
async def get_user_reviews(uid: str):
    """Fetch all reviews submitted by this user."""
    try:
        docs = db.collection("reviews").where("user_id", "==", uid).get()
        reviews = []
        for doc in docs:
            data = doc.to_dict()
            reviews.append(data)
        return reviews
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))