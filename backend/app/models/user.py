from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

class UserProfile(BaseModel):
    id: str  # Firebase UID
    name: Optional[str] = "User"
    email: Optional[str] = None
    role: str = "buyer"  # "buyer" or "seller"
    profile_image: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    role: Optional[str] = None
    device_token: Optional[str] = None
