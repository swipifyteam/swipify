from fastapi import APIRouter, HTTPException, Body
from firebase_client import db
import firebase_admin.auth as firebase_auth
from app.services.sms_service import sms_service
import random
import time
import logging
from google.cloud.firestore_v1 import SERVER_TIMESTAMP

logger = logging.getLogger(__name__)
router = APIRouter()

@router.post("/send")
async def send_sms_otp(phone_number: str = Body(..., embed=True), uid: str = Body(..., embed=True)):
    """
    Generates and sends an OTP to the specified phone number.
    Stores the OTP in Firestore for verification.
    """
    try:
        # Check if phone number is already in use by another user
        # We search the 'users' collection for this phone_number
        existing_users = db.collection("users").where("phone_number", "==", phone_number).limit(1).get()
        if len(existing_users) > 0:
            # If the user found is NOT the current requester, then it's a duplication
            if existing_users[0].id != uid:
                raise HTTPException(status_code=400, detail="This phone number is already linked to another account")

        # Generate 6-digit OTP
        otp = str(random.randint(100000, 999999))
        
        # Store in Firestore 'otps' collection
        otp_data = {
            "uid": uid,
            "phone_number": phone_number,
            "otp": otp,
            "expires_at": time.time() + 300, # 5 minutes
            "created_at": SERVER_TIMESTAMP
        }
        
        # Use phone_number as ID to easily find/throttle
        db.collection("otps").document(phone_number).set(otp_data)
        
        # Send via SMS API
        success = await sms_service.send_otp(phone_number, otp)
        
        if success:
            return {"status": "ok", "message": "OTP sent successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to send SMS via provider")
            
    except Exception as e:
        logger.error(f"Error in send_sms_otp: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/verify")
async def verify_sms_otp(
    uid: str = Body(..., embed=True),
    phone_number: str = Body(..., embed=True),
    otp: str = Body(..., embed=True)
):
    """
    Verifies the OTP and links the phone number to the Firebase Auth user.
    """
    try:
        doc_ref = db.collection("otps").document(phone_number)
        doc = doc_ref.get()
        
        if not doc.exists:
            raise HTTPException(status_code=400, detail="No OTP found for this number")
            
        data = doc.to_dict()
        
        # Check expiry
        if time.time() > data.get("expires_at", 0):
            doc_ref.delete()
            raise HTTPException(status_code=400, detail="OTP expired")
            
        # Check OTP
        if data.get("otp") != otp:
            raise HTTPException(status_code=400, detail="Invalid OTP")
            
        # Success! Link to Firebase User
        try:
            firebase_auth.update_user(
                uid,
                phone_number=phone_number
            )
            # Also update Firestore user profile
            db.collection("users").document(uid).update({
                "phone_number": phone_number,
                "phone_verified": True,
                "updated_at": SERVER_TIMESTAMP
            })
        except Exception as auth_err:
            error_str = str(auth_err)
            # Handle cases where phone is already in use
            if "already-exists" in error_str or "already in use" in error_str.lower():
                raise HTTPException(status_code=400, detail="Phone number is already linked to another account")
            
            # Specific error for disabled Phone Auth
            if "operation-not-allowed" in error_str or "Phone authentication is not enabled" in error_str:
                raise HTTPException(
                    status_code=500, 
                    detail="Phone authentication is not enabled in the Firebase Console. "
                           "Please go to Authentication > Sign-in method and enable the Phone provider."
                )
                
            raise HTTPException(status_code=500, detail=f"Firebase Auth update failed: {error_str}")
            
        # Clean up
        doc_ref.delete()
        
        return {"status": "ok", "message": "Phone number verified and linked"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in verify_sms_otp: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
