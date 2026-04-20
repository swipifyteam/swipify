from fastapi import Header, HTTPException

def get_current_user_id(authorization: str = Header(...)) -> str:
    """
    Extracts the user ID from the Authorization header.
    Assumes the Authorization header is in the format "Bearer <uid>".
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")
    
    parts = authorization.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Invalid Authorization header format. Expected 'Bearer <uid>'")
    
    uid = parts[1]
    if not uid:
        raise HTTPException(status_code=401, detail="User ID (UID) not found in token")
    
    return uid
