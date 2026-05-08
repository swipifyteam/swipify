from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime

class VoucherCreateRequest(BaseModel):
    seller_id: str
    code: str = Field(..., min_length=3, max_length=20)
    title: Optional[str] = None
    description: Optional[str] = None
    discount_type: str = Field(..., pattern="^(percentage|fixed)$")
    discount_target: str = Field(default="SUBTOTAL", pattern="^(SUBTOTAL|SHIPPING)$")
    discount_value: float = Field(..., gt=0)
    minimum_spend: float = Field(default=0.0, ge=0)
    max_discount: Optional[float] = Field(None, ge=0)
    usage_limit: int = Field(..., ge=1)
    start_date: datetime = Field(default_factory=datetime.now)
    end_date: datetime
    scope: str = "STORE"
    is_active: bool = True

    @field_validator('code')
    def validate_code(cls, v):
        return v.upper().strip()

    @field_validator('discount_value')
    def validate_discount_value(cls, v, info):
        if info.data.get('discount_type') == 'percentage' and v > 100:
            raise ValueError('Percentage discount cannot exceed 100%')
        return v

class VoucherUpdateRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    discount_type: Optional[str] = Field(None, pattern="^(percentage|fixed)$")
    discount_target: Optional[str] = Field(None, pattern="^(SUBTOTAL|SHIPPING)$")
    discount_value: Optional[float] = Field(None, gt=0)
    minimum_spend: Optional[float] = Field(None, ge=0)
    max_discount: Optional[float] = Field(None, ge=0)
    usage_limit: Optional[int] = Field(None, ge=1)
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    is_active: Optional[bool] = None

class VoucherAvailableRequest(BaseModel):
    user_id: Optional[str] = None
    seller_ids: List[str]
    cart_totals: dict[str, float] # seller_id -> total
    shipping_fees: Optional[dict[str, float]] = None

class VoucherApplyRequest(BaseModel):
    user_id: Optional[str] = None
    seller_id: str
    voucher_code: str
    cart_total: float = Field(..., gt=0)
    shipping_fee: Optional[float] = Field(None, ge=0)

class VoucherResponse(BaseModel):
    id: str
    seller_id: str
    code: str
    title: Optional[str] = None
    description: Optional[str] = None
    discount_type: str
    discount_target: str
    discount_value: float
    minimum_spend: float
    max_discount: Optional[float]
    usage_limit: int
    used_count: int
    total_quantity: Optional[int] = None
    remaining_quantity: Optional[int] = None
    claimed_count: Optional[int] = 0
    start_date: str
    end_date: str
    scope: str
    is_active: bool
    is_claimed: bool = False # Field to indicate if the requesting user has claimed it
    created_at: str

class VoucherClaimRequest(BaseModel):
    user_id: str
    voucher_id: str

class VoucherClaimResponse(BaseModel):
    success: bool
    message: str
    voucher: Optional[VoucherResponse] = None

class VoucherApplyResponse(BaseModel):
    discount: float
    final_total: float
    voucher_id: str
    code: str
    message: Optional[str] = None

class AvailableVouchersResponse(BaseModel):
    vouchers: List[VoucherResponse]
