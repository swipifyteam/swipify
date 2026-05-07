from fastapi import APIRouter, HTTPException, Body
from firebase_client import db
import firebase_admin.auth as firebase_auth
from app.services.sms_service import sms_service
import random
import time
import logging
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from app.config import get_settings

logger = logging.getLogger(__name__)
router = APIRouter()
settings = get_settings()

@router.post("/send")
async def send_sms_otp(phone_number: str = Body(..., embed=True), uid: str = Body(..., embed=True)):
    """
    Generates and sends an OTP to the specified phone number.
    Stores the OTP in Firestore for verification.
    """
    try:
        logger.info(f"[AUTH] Sending OTP to {phone_number} for UID: {uid}")
        
        # Verify user exists in Firebase Auth
        try:
            firebase_auth.get_user(uid)
        except Exception as e:
            error_str = str(e).lower()
            if "not-found" in error_str or "user-not-found" in error_str or "no user record found" in error_str:
                # Fallback check by phone
                try:
                    firebase_auth.get_user_by_phone_number(phone_number)
                except Exception as pe:
                    p_error_str = str(pe).lower()
                    if "not-found" in p_error_str or "user-not-found" in p_error_str or "no user record found" in p_error_str:
                        raise HTTPException(status_code=404, detail="User account not found. Please sign up first.")
            else:
                raise e

        # Check if phone number is already in use by another user
        # We search both 'phone_number' (new) and 'phone' (legacy)
        existing_users = db.collection("users").where("phone_number", "==", phone_number).limit(1).get()
        if not existing_users:
            existing_users = db.collection("users").where("phone", "==", phone_number).limit(1).get()

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
            # Check if it was a missing key or a provider error
            detail_msg = "Failed to send SMS via provider. Please check backend logs for details."
            if not settings.SMS_KEY and phone_number != "+639000000000":
                 detail_msg = "SMS configuration error: SMS_KEY is missing in backend environment variables."
            
            raise HTTPException(status_code=500, detail=detail_msg)
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in send_sms_otp: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

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
        logger.info(f"[AUTH] Verifying OTP for phone {phone_number} with UID: {uid}")
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
            try:
                # Attempt to update the user with the provided UID
                firebase_auth.update_user(
                    uid,
                    phone_number=phone_number
                )
                actual_uid = uid
            except Exception as e:
                error_str = str(e).lower()
                logger.warning(f"[AUTH] Initial update failed with error: {error_str}")
                if "not-found" in error_str or "not_found" in error_str or "no user record found" in error_str:
                    logger.warning(f"[AUTH] UID {uid} not found in Auth during update. Searching by phone {phone_number}...")
                    try:
                        user_record = firebase_auth.get_user_by_phone_number(phone_number)
                        actual_uid = user_record.uid
                        logger.info(f"[AUTH] Found user by phone. Correct UID is: {actual_uid}")
                        # Retry update with the correct UID
                        firebase_auth.update_user(
                            actual_uid,
                            phone_number=phone_number
                        )
                    except Exception as pe:
                        p_error_str = str(pe).lower()
                        if "not-found" in p_error_str or "not_found" in p_error_str or "no user record found" in p_error_str:
                            logger.error(f"[AUTH] User with phone {phone_number} also not found in Auth.")
                            raise HTTPException(status_code=404, detail="User account not found. Please sign up first.")
                        raise pe
                else:
                    raise e

            # Update Firestore for the correct UID
            db.collection("users").document(actual_uid).update({
                "phone_number": phone_number,
                "phone_verified": True,
                "updated_at": SERVER_TIMESTAMP
            })
            # Update the local variable for custom token generation
            uid = actual_uid

        except HTTPException:
            raise
        except Exception as auth_err:
            error_str = str(auth_err)
            logger.error(f"[AUTH] Auth link failed for {phone_number}: {error_str}")
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
        
        # Generate custom token for the user to sign in locally
        custom_token = firebase_auth.create_custom_token(uid)
        
        return {
            "status": "ok", 
            "message": "Phone number verified and linked",
            "custom_token": custom_token.decode('utf-8') if isinstance(custom_token, bytes) else custom_token
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in verify_sms_otp: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
