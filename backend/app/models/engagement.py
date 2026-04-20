from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class LikeRequest(BaseModel):
    user_id: str
    product_id: str

class RecentlyViewedRequest(BaseModel):
    user_id: str
    product_id: str

class RecentlyViewedResponse(BaseModel):
    product_id: str
    timestamp: datetime
