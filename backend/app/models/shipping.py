from pydantic import BaseModel, Field
from typing import List

class ShippingItem(BaseModel):
    product_id: str
    seller_id: str  # Required to find the shop's origin address
    quantity: int = Field(gt=0)
    weight_kg: float = Field(ge=0)

class ShippingCalculationRequest(BaseModel):
    items: List[ShippingItem]
    destination_postal_code: str  # Accept 4 or 5 digit Philippine postal codes

class ShippingOption(BaseModel):
    id: str
    name: str
    fee: float
    estimated_days_min: int
    estimated_days_max: int

class SelectedShippingOption(BaseModel):
    id: str
    name: str
    fee: float
    estimated_days_min: int
    estimated_days_max: int

class ShippingCalculationResponse(BaseModel):
    options: List[ShippingOption]
