from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class ReviewCreateRequest(BaseModel):
    user_id: str
    product_id: str
    order_id: str
    rating: int = Field(ge=1, le=5)
    comment: str
    image_urls: List[str] = []

class ReviewResponse(BaseModel):
    id: str
    user_id: str
    user_name: Optional[str] = "Anonymous"
    product_id: str
    order_id: str
    rating: int
    comment: str
    image_urls: List[str]
    created_at: str
