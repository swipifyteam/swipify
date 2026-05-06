from pydantic import BaseModel, Field
from typing import List, Optional

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

class ShipmentCreateRequest(BaseModel):
    order_id: str
    courier_id: str

class ShipmentLocation(BaseModel):
    lat: float
    lng: float

class ShipmentResponse(BaseModel):
    shipment_id: str
    tracking_number: str
    courier: str
    label_url: str

class WebhookPayload(BaseModel):
    event_type: str  # e.g., 'shipment.status.updated'
    shipment_id: str
    tracking_number: str
    status: str      # e.g., 'shipped', 'in_transit', 'out_for_delivery', 'delivered'
    location: Optional[ShipmentLocation] = None

