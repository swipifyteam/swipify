from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime

class VoucherCreateRequest(BaseModel):
    seller_id: str
    code: str = Field(..., min_length=3, max_length=20)
    discount_type: str = Field(..., pattern="^(percentage|fixed)$")
    discount_target: str = Field(default="SUBTOTAL", pattern="^(SUBTOTAL|SHIPPING)$")
    discount_value: float = Field(..., gt=0)
    min_order_amount: float = Field(default=0.0, ge=0)
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
    discount_type: Optional[str] = Field(None, pattern="^(percentage|fixed)$")
    discount_target: Optional[str] = Field(None, pattern="^(SUBTOTAL|SHIPPING)$")
    discount_value: Optional[float] = Field(None, gt=0)
    min_order_amount: Optional[float] = Field(None, ge=0)
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
    discount_type: str
    discount_target: str
    discount_value: float
    min_order_amount: float
    max_discount: Optional[float]
    usage_limit: int
    used_count: int
    start_date: str
    end_date: str
    scope: str
    is_active: bool
    created_at: str

class VoucherApplyResponse(BaseModel):
    discount: float
    final_total: float
    voucher_id: str
    code: str
    message: Optional[str] = None

class AvailableVouchersResponse(BaseModel):
    vouchers: List[VoucherResponse]
