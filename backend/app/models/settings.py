from pydantic import BaseModel
from typing import List, Optional

class PlatformSettings(BaseModel):
    commission_rate: float = 0.05
    payout_threshold: float = 50.0
    maintenance_mode: bool = False
    allowed_categories: List[str] = ["Electronics", "Fashion", "Home", "Beauty", "Sports"]
    support_email: str = "support@swipify.com"

class PlatformSettingsUpdateRequest(BaseModel):
    commission_rate: Optional[float] = None
    payout_threshold: Optional[float] = None
    maintenance_mode: Optional[bool] = None
    allowed_categories: Optional[List[str]] = None
    support_email: Optional[str] = None
