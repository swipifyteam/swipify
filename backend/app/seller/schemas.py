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
    # Address details for shipping origin
    street: Optional[str] = None
    barangay: Optional[str] = None
    city: Optional[str] = None
    province: Optional[str] = None
    postal_code: Optional[str] = None

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

# --- SELLER PRODUCTS SCHEMAS ---

class ProductCreateRequest(BaseModel):
    name: str
    description: str
    price: float
    stock: int
    category: str
    images: List[str]
    sku: Optional[str] = None
    is_published: Optional[bool] = True

class ProductUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    category: Optional[str] = None
    images: Optional[List[str]] = None
    sku: Optional[str] = None
    is_published: Optional[bool] = None

class BulkActionRequest(BaseModel):
    product_ids: List[str]
    action: str  # publish, unpublish, archive
    category: Optional[str] = None  # for update_category action

class StockUpdateRequest(BaseModel):
    adjustment: int  # +/- value
