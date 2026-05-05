from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from enum import Enum

from app.models.shipping import SelectedShippingOption

class OrderStatus(str, Enum):
    PENDING = "pending"
    PAID = "paid"
    PROCESSING = "processing"
    READY_FOR_SHIPMENT = "ready_for_shipment"
    LABEL_CREATED = "label_created"
    SHIPPED = "shipped"
    IN_TRANSIT = "in_transit"
    OUT_FOR_DELIVERY = "out_for_delivery"
    DELIVERED = "delivered"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    EXCEPTION = "exception"

VALID_ORDER_TRANSITIONS = {
    OrderStatus.PENDING: {OrderStatus.PROCESSING, OrderStatus.PAID, OrderStatus.CANCELLED},
    OrderStatus.PAID: {OrderStatus.PROCESSING, OrderStatus.CANCELLED},
    OrderStatus.PROCESSING: {OrderStatus.READY_FOR_SHIPMENT, OrderStatus.SHIPPED, OrderStatus.CANCELLED},
    OrderStatus.READY_FOR_SHIPMENT: {OrderStatus.LABEL_CREATED, OrderStatus.SHIPPED, OrderStatus.CANCELLED},
    OrderStatus.LABEL_CREATED: {OrderStatus.SHIPPED, OrderStatus.CANCELLED},
    OrderStatus.SHIPPED: {OrderStatus.IN_TRANSIT, OrderStatus.DELIVERED, OrderStatus.EXCEPTION},
    OrderStatus.IN_TRANSIT: {OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERED, OrderStatus.EXCEPTION},
    OrderStatus.OUT_FOR_DELIVERY: {OrderStatus.DELIVERED, OrderStatus.EXCEPTION},
    OrderStatus.DELIVERED: {OrderStatus.COMPLETED},
    OrderStatus.COMPLETED: set(),
    OrderStatus.CANCELLED: set(),
    OrderStatus.EXCEPTION: {OrderStatus.SHIPPED, OrderStatus.CANCELLED},
}

class OrderItem(BaseModel):
    product_id: str
    name: str
    price: float
    quantity: int
    image_url: Optional[str] = None # Added for UI snapshots

class AddressSnapshot(BaseModel):
    full_name: str
    phone: str
    region: str
    city: str
    barangay: str
    street: str
    postal_code: str

class OrderCreateRequest(BaseModel):
    user_id: str
    seller_id: str
    items: List[OrderItem]
    total_price: float
    selected_shipping_option: SelectedShippingOption
    shipping_address: AddressSnapshot
    logistic_provider: Optional[str] = "Standard Logistics"
    tracking_number: Optional[str] = None
    discount_amount: Optional[float] = 0.0
    voucher_id: Optional[str] = None
    payment_method: str = "online" # "online" or "cod"

class OrderStatusUpdateRequest(BaseModel):
    status: OrderStatus # Use the Enum for status

class OrderPaymentUpdateRequest(BaseModel):
    payment_status: str # unpaid, paid, failed

class BuyNowRequest(BaseModel):
    user_id: str
    product_id: str
    quantity: int
    selected_shipping_option: SelectedShippingOption
    shipping_address: AddressSnapshot
    payment_method: str = "online"

class StatusHistoryEntry(BaseModel):
    timestamp: str
    old_status: Optional[str] = None
    new_status: str
    updated_by: Optional[str] = "system"
    notes: Optional[str] = None

class OrderResponse(BaseModel):
    id: str
    user_id: str
    seller_id: str
    items: List[OrderItem]
    total_price: float
    status: OrderStatus # Use the Enum for status
    payment_method: Optional[str] = "online"
    payment_status: Optional[str] = "pending"
    is_cod_confirmed: Optional[bool] = False
    created_at: str
    updated_at: str
    shipping_details: Optional[SelectedShippingOption] = None
    shipping_address: Optional[AddressSnapshot] = None
    logistic_provider: Optional[str] = None
    tracking_number: Optional[str] = None
    discount_amount: Optional[float] = 0.0
    voucher_id: Optional[str] = None
    status_history: Optional[List[StatusHistoryEntry]] = None
    last_location_update: Optional[str] = None
    estimated_arrival_time: Optional[str] = None

class TrackingResponse(BaseModel):
    tracking_number: Optional[str]
    status: str
    status_history: List[StatusHistoryEntry]
    courier: Optional[str]
    last_location_update: Optional[str] = None
    estimated_arrival_time: Optional[str] = None

class CalculateTotalRequest(BaseModel):
    distance_km: float
    weight_kg: float
    subtotal: float
    shipping_fee: Optional[float] = None
    provider_id: Optional[str] = "standard"

class CalculateTotalResponse(BaseModel):
    subtotal: float
    shipping_fee: float
    total: float
