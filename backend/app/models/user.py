from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

class UserProfile(BaseModel):
    id: str  # Firebase UID
    name: Optional[str] = "User"
    username: Optional[str] = None
    email: Optional[str] = None
    phone_number: Optional[str] = None
    gender: Optional[str] = None  # "male", "female", "other"
    date_of_birth: Optional[str] = None  # ISO date string "YYYY-MM-DD"
    role: str = "buyer"  # "buyer" or "seller"
    profile_image: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class UserUpdateRequest(BaseModel):
    name: Optional[str] = None
    username: Optional[str] = None
    phone_number: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    role: Optional[str] = None
    device_token: Optional[str] = None
