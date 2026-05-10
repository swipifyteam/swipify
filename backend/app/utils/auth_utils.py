from fastapi import HTTPException, Security, Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth
from firebase_client import db
import logging

logger = logging.getLogger(__name__)
security = HTTPBearer()

def get_current_user(res: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """
    Verifies the Firebase ID Token passed in the Authorization header.
    Returns the decoded token (which contains 'uid', 'email', etc).
    """
    token = res.credentials
    try:
        decoded_token = auth.verify_id_token(token)
        # Fetch user role from Firestore to ensure it's up to date
        uid = decoded_token.get("uid")
        if uid:
            user_doc = db.collection("users").document(uid).get()
            if user_doc.exists:
                user_data = user_doc.to_dict()
                decoded_token["role"] = user_data.get("role", "buyer")
        return decoded_token
    except Exception as e:
        logger.error(f"Auth error: {e}")
        raise HTTPException(
            status_code=401,
            detail=f"Invalid or expired token: {str(e)}"
        )

def require_role(allowed_roles: list):
    """
    Dependency factory to restrict access based on user roles.
    """
    def role_checker(user: dict = Depends(get_current_user)):
        role = user.get("role")
        if role not in allowed_roles:
            logger.warning(f"Role mismatch: {role} not in {allowed_roles}")
            raise HTTPException(
                status_code=403,
                detail=f"Operation not permitted. Required roles: {allowed_roles}"
            )
        return user
    return role_checker

async def require_admin(user: dict = Depends(get_current_user)):
    """
    Dependency to restrict access to users with 'admin' or 'super_admin' roles.
    """
    role = user.get("role")
    if role not in ["admin", "super_admin"]:
        logger.warning(f"Admin access denied for role: {role}")
        raise HTTPException(
            status_code=403,
            detail="Admin privileges required."
        )
    return user

def verify_owner(user_id: str, token_uid: str):
    """
    Ensures that the requested user_id matches the authenticated token's uid.
    Used to prevent IDOR (Insecure Direct Object Reference).
    """
    if user_id != token_uid:
        raise HTTPException(
            status_code=403,
            detail="Operation not permitted. Identity mismatch."
        )
