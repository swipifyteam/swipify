# backend/app/models/address.py

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class AddressCreateRequest(BaseModel):
    user_id: str
    full_name: str
    phone: str = Field(..., pattern=r"^\+63\d{10}$")
    region: str
    city: str
    barangay: str
    street: str
    postal_code: str = Field(..., pattern=r"^\d{5}$")
    is_default: Optional[bool] = False

class AddressUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = Field(None, pattern=r"^\+63\d{10}$")
    region: Optional[str] = None
    city: Optional[str] = None
    barangay: Optional[str] = None
    street: Optional[str] = None
    postal_code: Optional[str] = Field(None, pattern=r"^\d{5}$")
    is_default: Optional[bool] = None

class AddressResponse(BaseModel):
    id: str
    user_id: str
    full_name: str
    phone: str
    region: str
    city: str
    barangay: str
    street: str
    postal_code: str
    is_default: bool
    created_at: str
    updated_at: str
