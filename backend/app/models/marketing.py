from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

# --- FLASH SALES ---
class FlashSaleCreateRequest(BaseModel):
    seller_id: str
    product_id: str
    discount_price: float = Field(..., gt=0)
    start_time: datetime
    end_time: datetime
    stock_limit: int = Field(..., ge=1)
    is_active: bool = True


class FlashSaleResponse(BaseModel):
    id: str
    seller_id: str
    product_id: str
    discount_price: float
    start_time: str
    end_time: str
    stock_limit: int
    sold_count: int
    is_active: bool
    created_at: str


# --- BUNDLE DEALS ---
class BundleDealCreateRequest(BaseModel):
    seller_id: str
    name: str
    product_ids: List[str]
    min_quantity: int = Field(default=2, ge=2)
    discount_percentage: float = Field(..., gt=0, le=100)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    is_active: bool = True


class BundleDealResponse(BaseModel):
    id: str
    seller_id: str
    name: str
    product_ids: List[str]
    min_quantity: int
    discount_percentage: float
    start_time: Optional[str]
    end_time: Optional[str]
    is_active: bool
    created_at: str


# --- LOYALTY POINTS ---
class LoyaltyConfigSaveRequest(BaseModel):
    seller_id: str
    points_per_peso: float = Field(default=0.01, ge=0)
    min_redeem_points: int = Field(default=10, ge=0)
    is_enabled: bool = True


class LoyaltyConfigResponse(BaseModel):
    seller_id: str
    points_per_peso: float
    min_redeem_points: int
    is_enabled: bool
    updated_at: str

# --- PLATFORM VOUCHERS ---
class PlatformVoucherCreateRequest(BaseModel):
    code: str = Field(..., min_length=3, max_length=20)
    discount_type: str = Field(..., pattern="^(percentage|fixed)$")
    value: float = Field(..., gt=0)
    min_spend: float = Field(default=0.0, ge=0)
    start_date: datetime = Field(default_factory=datetime.now)
    end_date: datetime
    max_usage: Optional[int] = Field(None, ge=1)

class PlatformVoucherResponse(BaseModel):
    id: str
    code: str
    discount_type: str
    value: float
    min_spend: float
    start_date: str
    end_date: str
    usage_count: int
    max_usage: Optional[int]
    created_at: str

class PlatformVoucherUpdateRequest(BaseModel):
    """Partial update model for platform vouchers."""
    code: Optional[str] = None
    discount_type: Optional[str] = Field(None, pattern="^(percentage|fixed)$")
    value: Optional[float] = Field(None, gt=0)
    min_spend: Optional[float] = Field(None, ge=0)
    end_date: Optional[datetime] = None
    max_usage: Optional[int] = Field(None, ge=1)

