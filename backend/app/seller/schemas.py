# app/seller/schemas.py
# Pydantic schemas for Seller endpoints

from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from enum import Enum

class SellerStatusEnum(str, Enum):
    NOT_APPLIED = "NOT_APPLIED"
    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REJECTED = "REJECTED"

class SellerApplicationRequest(BaseModel):
    user_id: str
    store_name: str
    seller_type: str
    bank_name: str
    account_number: str
    identity_image_url: Optional[str] = None
    selfie_image_url: Optional[str] = None
    agree_to_terms: bool

class ApproveRejectRequest(BaseModel):
    seller_id: str
    reason: Optional[str] = None

class SellerStatusResponse(BaseModel):
    status: SellerStatusEnum
    seller: Optional[Dict[str, Any]] = None

class UploadDocumentResponse(BaseModel):
    message: str
    file_url: str
    document_id: str
