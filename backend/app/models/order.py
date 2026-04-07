from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class OrderItem(BaseModel):
    product_id: str
    name: str
    price: float
    quantity: int

class OrderCreateRequest(BaseModel):
    """
    Request payload when creating an order from cart.
    Will be grouped by seller on the backend if needed, or frontend sends by seller.
    For simplicity, assuming frontend groups items by seller and creates an order per seller.
    """
    user_id: str
    seller_id: str
    items: List[OrderItem]
    total_price: float

class OrderStatusUpdateRequest(BaseModel):
    status: str # pending, paid, processing, shipped, delivered, cancelled

class OrderPaymentUpdateRequest(BaseModel):
    payment_status: str # unpaid, paid, failed

class BuyNowRequest(BaseModel):
    user_id: str
    product_id: str
    quantity: int

class OrderResponse(BaseModel):
    id: str
    user_id: str
    seller_id: str
    items: List[OrderItem]
    total_price: float
    status: str
    payment_status: str
    created_at: str
    updated_at: str
