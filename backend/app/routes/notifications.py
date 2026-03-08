# app/routes/notifications.py
# Notification API endpoints for the Swipify ecommerce platform.
# Handles fetching a user's notifications and marking them as read.

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from firebase_client import db

router = APIRouter()


class MarkReadRequest(BaseModel):
    """Request body for marking notifications as read."""
    notificationIds: List[str]


@router.get("/{user_id}")
async def get_notifications(user_id: str):
    """Fetch all notifications for a specific user, ordered by creation time (newest first)."""
    try:
        docs = (
            db.collection("notifications")
            .where("userId", "==", user_id)
            .order_by("createdAt", direction="DESCENDING")
            .get()
        )
        notifications = []
        for doc in docs:
            notification = doc.to_dict()
            notification["id"] = doc.id
            # Convert Firestore timestamp to ISO string for JSON serialization
            if "createdAt" in notification and notification["createdAt"] is not None:
                notification["createdAt"] = notification["createdAt"].isoformat()
            notifications.append(notification)

        # Count unread notifications for the badge
        unread_count = sum(1 for n in notifications if not n.get("isRead", True))

        return {
            "userId": user_id,
            "notifications": notifications,
            "unreadCount": unread_count,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/read")
async def mark_as_read(request: MarkReadRequest):
    """Mark one or more notifications as read for a user.
    
    Accepts a list of notification IDs to mark as read in a batch.
    """
    try:
        batch = db.batch()
        for notification_id in request.notificationIds:
            doc_ref = db.collection("notifications").document(notification_id)
            batch.update(doc_ref, {"isRead": True})
        batch.commit()

        return {"message": f"{len(request.notificationIds)} notification(s) marked as read"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
