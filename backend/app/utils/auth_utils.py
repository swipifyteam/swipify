from fastapi import HTTPException, Security
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth
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
        return decoded_token
    except Exception as e:
        logger.error(f"Auth error: {e}")
        raise HTTPException(
            status_code=401,
            detail=f"Invalid or expired token: {str(e)}"
        )

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
