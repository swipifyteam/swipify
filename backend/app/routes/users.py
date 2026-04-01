# backend/app/routes/users.py
from fastapi import APIRouter, HTTPException
from firebase_client import db

router = APIRouter()

@router.get("/{uid}")
async def get_user_data(uid: str):
    """Retrieve user document from Firestore."""
    doc = db.collection("users").document(uid).get()
    if not doc.exists:
        # Create a default user document if it doesn't exist
        user_data = {
            "uid": uid,
            "seller_status": "NONE",
            "role": "user",
            "created_at": None
        }
        db.collection("users").document(uid).set(user_data)
        return user_data
    
    return doc.to_dict()

@router.get("/all")
async def get_users():
    docs = db.collection("users").get()
    return {"users": [doc.to_dict() for doc in docs]}

@router.put("/{uid}")
async def update_user_data(uid: str, data: dict):
    """Create or update user document in Firestore."""
    db.collection("users").document(uid).set(data, merge=True)
    return {"status": "ok", "message": "User updated"}