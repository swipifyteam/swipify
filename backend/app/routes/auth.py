from fastapi import APIRouter, HTTPException, Body, BackgroundTasks
from firebase_client import db
import firebase_admin.auth as firebase_auth
from app.services.email_service import email_service
from pydantic import BaseModel, EmailStr
import time
import logging
from google.cloud.firestore_v1 import SERVER_TIMESTAMP

logger = logging.getLogger(__name__)
router = APIRouter()

class OTPRequest(BaseModel):
    email: EmailStr
    user_id: str

class OTPVerifyRequest(BaseModel):
    email: EmailStr
    otp: str

@router.post("/send-otp")
async def send_email_otp(background_tasks: BackgroundTasks, request: OTPRequest):
    """
    Generates and sends an OTP to the specified email address.
    Uses BackgroundTasks to prevent blocking the response.
    """
    try:
        # Check if email is already in use by another user (Optional but recommended)
        existing_users = db.collection("users").where("email", "==", request.email).limit(1).get()
        if len(existing_users) > 0:
            if existing_users[0].id != request.user_id:
                raise HTTPException(status_code=400, detail="This email is already linked to another account")

        # Send OTP via background task
        background_tasks.add_task(email_service.send_otp_email, request.user_id, request.email)
        
        return {"status": "ok", "message": "Verification code sent to email"}
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in send_email_otp: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/verify-otp")
async def verify_email_otp(request: OTPVerifyRequest):
    """
    Verifies the OTP and marks the user as verified in Firestore.
    """
    try:
        doc_ref = db.collection("otps_email").document(request.email)
        doc = doc_ref.get()
        
        if not doc.exists:
            raise HTTPException(status_code=400, detail="No verification code found for this email")
            
        data = doc.to_dict()
        
        # Check expiry
        if time.time() > data.get("expires_at", 0):
            doc_ref.delete()
            raise HTTPException(status_code=400, detail="Verification code expired")
            
        # Check OTP
        if data.get("code") != request.otp:
            raise HTTPException(status_code=400, detail="Invalid verification code")
            
        # Success! 
        user_id = data.get("user_id")
        
        # Update user profile in Firestore
        db.collection("users").document(user_id).update({
            "email_verified": True,
            "updated_at": SERVER_TIMESTAMP
        })
        
        # Clean up OTP
        doc_ref.delete()
        
        return {"status": "ok", "message": "Email verified successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in verify_email_otp: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
