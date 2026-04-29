from fastapi import Header, HTTPException, Depends
import firebase_admin.auth
from firebase_client import db


def get_current_user_id(authorization: str = Header(None)) -> str:
    """
    Extracts and verifies the Firebase JWT token from the Authorization header.
    Returns the user's UID.
    """
    if not authorization:
        raise HTTPException(status_code=401, detail="Authorization header missing")

    parts = authorization.split(" ")
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=401,
            detail="Invalid Authorization header format. Expected 'Bearer <token>'"
        )

    token = parts[1]

    try:
        decoded_token = firebase_admin.auth.verify_id_token(token)
        return decoded_token["uid"]

    except firebase_admin.auth.InvalidIdTokenError:
        raise HTTPException(status_code=401, detail="Invalid authentication token")

    except firebase_admin.auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Authentication token expired")

    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")


def get_current_user(uid: str = Depends(get_current_user_id)) -> dict:
    user_ref = db.collection("users").document(uid).get()

    if not user_ref.exists:
        raise HTTPException(status_code=404, detail="User not found")

    user_data = user_ref.to_dict()
    user_data["uid"] = uid
    return user_data


def require_role(allowed_roles: list[str]):
    def role_checker(user: dict = Depends(get_current_user)):
        user_role = user.get("role", "buyer")

        if user_role not in allowed_roles and user_role != "super_admin":
            raise HTTPException(status_code=403, detail="Not enough permissions")

        return user

    return role_checker


def require_admin(user: dict = Depends(get_current_user)):
    admin_roles = [
        "super_admin",
        "operations_admin",
        "finance_admin",
        "moderator",
        "support_admin"
    ]

    user_role = user.get("role", "buyer")

    if user_role not in admin_roles:
        raise HTTPException(status_code=403, detail="Admin access required")

    return user