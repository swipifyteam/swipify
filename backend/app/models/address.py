from pydantic import BaseModel, Field, field_validator
from typing import Optional
import re

class AddressCreateRequest(BaseModel):
    user_id: str
    full_name: str = Field(..., min_length=2)
    phone: str = Field(..., pattern=r'^(\+|0)?[0-9]{7,15}$') 
    province: str = Field(..., min_length=1)
    city: str = Field(..., min_length=1)
    barangay: str = Field(..., min_length=1)
    street: str = Field(..., min_length=1)
    postal_code: str = Field(..., min_length=4)
    is_default: Optional[bool] = False

    @field_validator('full_name', 'phone', 'province', 'city', 'barangay', 'street', 'postal_code')
    def not_empty(cls, v):
        if isinstance(v, str) and not v.strip():
            raise ValueError('Field cannot be empty or just whitespace')
        return v.strip() if isinstance(v, str) else v

class AddressUpdateRequest(BaseModel):
    full_name: Optional[str] = Field(None, min_length=2)
    phone: Optional[str] = Field(None, pattern=r'^(\+|0)?[0-9]{7,15}$')
    province: Optional[str] = Field(None)
    city: Optional[str] = Field(None)
    barangay: Optional[str] = Field(None)
    street: Optional[str] = Field(None)
    postal_code: Optional[str] = Field(None, min_length=4)
    is_default: Optional[bool] = None

class AddressResponse(BaseModel):
    id: str
    user_id: str
    full_name: str
    phone: str
    province: str
    city: str
    barangay: str
    street: str
    postal_code: str
    is_default: bool
    created_at: str
    updated_at: str
