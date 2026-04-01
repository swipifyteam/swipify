# backend/app/routes/engagement.py
# Smart Engagement API for Swipify (User Retention System).
# This route handles specialized engagement triggers like re-engaging inactive users.
# Debug logs follow [NOTIF] prefix convention.

from fastapi import APIRouter, HTTPException
from app.utils.notifications import broadcast_notification
from pydantic import BaseModel

router = APIRouter()

class EngagementRequest(BaseModel):
    message: str = "We miss you! Check out new deals 🔥"

@router.post("/re-engage")
async def trigger_re_engagement(request: EngagementRequest):
    """Manually triggers a re-engagement broadcast to all users.
    In a production system, this would be triggered by a CRON job for inactive users.
    """
    try:
        print("[NOTIF] Smart Engagement: Triggering re-engagement broadcast")
        count = broadcast_notification(
            title="We miss you! 🔥",
            message=request.message,
            notification_type="PROMOTION"
        )
        return {"message": "Re-engagement broadcast sent", "users_notified": count}
    except Exception as e:
        print(f"[NOTIF] Engagement Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/trending")
async def broadcast_trending(product_name: str):
    """Simulates broadcasting a trending product to boost engagement."""
    try:
        print(f"[NOTIF] Smart Engagement: Broadcasting trending product: {product_name}")
        count = broadcast_notification(
            title="Trending Now! ⚡",
            message=f"{product_name} is selling fast! Get yours now.",
            notification_type="PROMOTION"
        )
        return {"message": "Trending broadcast sent", "users_notified": count}
    except Exception as e:
        print(f"[NOTIF] Engagement Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
