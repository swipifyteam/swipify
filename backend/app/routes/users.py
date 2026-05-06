from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from firebase_client import db
from app.models.user import UserProfile, UserUpdateRequest
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
import firebase_admin.auth as firebase_auth
import cloudinary
import cloudinary.uploader
import os
from dotenv import load_dotenv
from datetime import datetime
import logging

load_dotenv()

logger = logging.getLogger(__name__)

# Cloudinary Configuration
cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)

router = APIRouter()


def _resolve_auth_user_data(uid: str) -> dict:
    """Fetch real email/name from Firebase Auth. Never returns placeholders.
    Null-safety: if name is missing, defaults to 'User [Last 4 of UID]'.
    """
    real_email = None
    real_name = None
    try:
        auth_record = firebase_auth.get_user(uid)
        real_email = auth_record.email
        real_name = auth_record.display_name
    except Exception as e:
        logger.warning(f"[AUTH FIX] Could not fetch Auth record for {uid}: {e}")

    # [AUTH FIX] Null-safety fallbacks: No "New User" or "@placeholder.com"
    if not real_name or real_name.strip() in ["", "New User"]:
        real_name = f"User {uid[-4:]}"
    if not real_email or real_email.strip() == "" or real_email.endswith("@placeholder.com"):
        # Attempt to get email from auth_record if it was missing in Firestore
        real_email = real_email if real_email and not real_email.endswith("@placeholder.com") else None

    return {"name": real_name, "email": real_email}


@router.get("/{uid}", response_model=UserProfile)
async def get_user_profile(uid: str):
    """Retrieve user profile from Firestore."""
    try:
        doc = db.collection("users").document(uid).get()
        if not doc.exists:
            # [AUTH FIX] Fetch real data from Firebase Auth — NO placeholders
            auth_data = _resolve_auth_user_data(uid)
            user_data = {
                "id": uid, # Ensure UID matches Doc ID
                "name": auth_data["name"],
                "email": auth_data["email"],
                "display_name": auth_data["name"],
                "role": "buyer",
                "created_at": SERVER_TIMESTAMP,
                "updated_at": SERVER_TIMESTAMP
            }
            db.collection("users").document(uid).set(user_data)
            logger.info(f"[AUTH FIX] Real Email/Name mapped for UID: {uid}")
            # Fetch again to get the server-generated timestamps
            doc = db.collection("users").document(uid).get()
        else:
            # [AUTH FIX] Heal existing placeholder records on read
            data = doc.to_dict()
            needs_heal = False
            heal_data = {}
            
            # Check for placeholder email or "New User" name
            current_email = data.get("email") or ""
            current_name = data.get("name") or ""
            
            if current_email.endswith("@placeholder.com") or current_name == "New User" or not current_name:
                auth_data = _resolve_auth_user_data(uid)
                heal_data["email"] = auth_data["email"]
                heal_data["name"] = auth_data["name"]
                heal_data["display_name"] = auth_data["name"]
                heal_data["updated_at"] = SERVER_TIMESTAMP
                needs_heal = True

            if needs_heal:
                db.collection("users").document(uid).update(heal_data)
                logger.info(f"[AUTH FIX] Real Email/Name mapped for UID: {uid}")
                doc = db.collection("users").document(uid).get()

        data = doc.to_dict()
        data["id"] = doc.id  # Assign doc ID directly
        # Handle timestamp conversion
        for key in ["created_at", "updated_at"]:
            if data.get(key) and hasattr(data[key], "isoformat"):
                data[key] = data[key].isoformat()

        return data
    except Exception as e:
        logger.error(f"[USER ERROR] Fetch failed: {e}")
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

@router.get("/by-phone/{phone_number}")
async def get_user_by_phone(phone_number: str):
    """Search for a user by their phone number. Returns public info if found."""
    try:
        # Search for user in Firestore
        docs = db.collection("users").where("phone_number", "==", phone_number.strip()).limit(1).get()
        
        if not docs:
            raise HTTPException(status_code=404, detail="No user found with this phone number")
            
        user_doc = docs[0]
        user_data = user_doc.to_dict()
        
        # Return minimal data for security
        return {
            "uid": user_doc.id,
            "name": user_data.get("name", "User"),
            "email_masked": _mask_email(user_data.get("email", ""))
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[USER ERROR] Phone lookup failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def _mask_email(email: str) -> str:
    if not email or "@" not in email:
        return "***"
    parts = email.split("@")
    name = parts[0]
    domain = parts[1]
    if len(name) <= 2:
        return f"*@{domain}"
    return f"{name[0]}***{name[-1]}@{domain}"

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