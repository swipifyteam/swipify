from fastapi import APIRouter, HTTPException, Body, BackgroundTasks
from firebase_client import db
import firebase_admin.auth as firebase_auth
from app.services.email_service import email_service
from pydantic import BaseModel, EmailStr
import time
import logging
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from app.models.address import AddressCreateRequest
from app.services.address_service import create_address_service

logger = logging.getLogger(__name__)
router = APIRouter()

class OTPRequest(BaseModel):
    email: EmailStr
    user_id: str

class OTPVerifyRequest(BaseModel):
    email: EmailStr
    otp: str

class AddressSignup(BaseModel):
    street: str
    barangay: str
    city: str
    province: str
    postal_code: str

class SignupRequest(BaseModel):
    name: str
    email: EmailStr
    password: str
    phone: str
    address: AddressSignup

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

@router.post("/signup")
async def signup(request: SignupRequest):
    """
    Complete Signup:
    1. Create Firebase Auth user
    2. Save user in Firestore
    3. Create address document
    4. Set is_default = true
    """
    try:
        # 1. Create Firebase Auth user
        try:
            auth_user = firebase_auth.create_user(
                email=request.email,
                password=request.password,
                display_name=request.name,
                phone_number=request.phone if request.phone.startswith("+") else None # Firebase requires + for phone
            )
            user_id = auth_user.uid
            print(f"[USER CREATED] UID: {user_id}")
        except Exception as e:
            if "EMAIL_EXISTS" in str(e) or "already in use" in str(e):
                raise HTTPException(status_code=400, detail="Email already exists")
            raise HTTPException(status_code=400, detail=f"Auth Error: {str(e)}")

        # 2. Save user in Firestore
        user_data = {
            "name": request.name,
            "email": request.email,
            "phone": request.phone,
            "role": "buyer",
            "created_at": SERVER_TIMESTAMP,
            "updated_at": SERVER_TIMESTAMP,
            "email_verified": False
        }
        db.collection("users").document(user_id).set(user_data)

        # 3. Create address document
        address_data = AddressCreateRequest(
            user_id=user_id,
            full_name=request.name,
            phone=request.phone,
            street=request.address.street,
            barangay=request.address.barangay,
            city=request.address.city,
            province=request.address.province,
            postal_code=request.address.postal_code,
            is_default=True
        )
        
        create_address_service(address_data)
        print(f"[DEFAULT ADDRESS CREATED] for UID: {user_id}")

        return {
            "status": "ok",
            "message": "User created successfully",
            "user_id": user_id
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in signup: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


class SocialLoginRequest(BaseModel):
    id_token: str

@router.post("/social-login")
async def social_login(request: SocialLoginRequest):
    """
    Verify a Firebase ID token from a social login (Google/Facebook).
    Creates the user document in Firestore if it doesn't exist.
    Returns the user profile.
    """
    try:
        # 1. Verify the Firebase ID token
        decoded_token = firebase_auth.verify_id_token(request.id_token)
        uid = decoded_token['uid']
        email = decoded_token.get('email', '')
        name = decoded_token.get('name', '')
        picture = decoded_token.get('picture', '')
        provider = decoded_token.get('firebase', {}).get('sign_in_provider', 'unknown')

        logger.info(f"[SOCIAL LOGIN] Verified token for UID: {uid}, provider: {provider}")

        # 2. Check if user document already exists
        user_ref = db.collection("users").document(uid)
        user_doc = user_ref.get()

        if user_doc.exists:
            logger.info(f"[SOCIAL LOGIN] User {uid} already exists, returning profile")
            user_data = user_doc.to_dict()
            user_data['uid'] = uid
            return {"status": "ok", "user": user_data, "is_new": False}

        # 3. Create new user document for first-time social login
        user_data = {
            "name": name,
            "email": email,
            "photo_url": picture,
            "role": "buyer",
            "provider": provider,
            "created_at": SERVER_TIMESTAMP,
            "updated_at": SERVER_TIMESTAMP,
            "email_verified": bool(email),
            "seller_status": "NONE",
        }
        user_ref.set(user_data)
        logger.info(f"[SOCIAL LOGIN] Created new user document for UID: {uid}")

        user_data['uid'] = uid
        return {"status": "ok", "user": user_data, "is_new": True}

    except ValueError as e:
        logger.warning(f"[SOCIAL LOGIN] Invalid token: {str(e)}")
        raise HTTPException(status_code=401, detail="Invalid or expired ID token")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[SOCIAL LOGIN] Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
