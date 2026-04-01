# backend/app/routes/notifications.py
# Notification API endpoints for the Swipify ecommerce platform.
# Handles fetching a user's notifications and marking them as read.
# Debug logs follow [NOTIF] prefix convention.

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP

router = APIRouter()

class MarkReadRequest(BaseModel):
    """Request body for marking notifications as read."""
    notificationIds: List[str]

@router.get("/{user_id}")
async def get_notifications(user_id: str):
    """Fetch all notifications for a specific user, with safe timestamp handling."""
    try:
        print(f"[NOTIF] Fetching notifications for user: {user_id}")
        
        # 1. Fetch from Firestore (Try order_by, fallback if index missing)
        try:
            docs = (
                db.collection("notifications")
                .where("user_id", "==", user_id)
                .order_by("created_at", direction="DESCENDING")
                .get()
            )
        except Exception as order_error:
            print(f"[NOTIF] order_by failed (index missing?): {order_error}")
            # Fallback: simple fetch without order_by
            docs = (
                db.collection("notifications")
                .where("user_id", "==", user_id)
                .get()
            )
        
        notifications = []
        for doc in docs:
            notification = doc.to_dict()
            notification["id"] = doc.id
            
            # Convert Firestore timestamp to ISO string only if it's a datetime object
            ca = notification.get("created_at")
            if ca and hasattr(ca, "isoformat"):
                notification["created_at"] = ca.isoformat()
            
            notifications.append(notification)

        # 2. Sort in memory as fallback if the firestore query wasn't ordered
        notifications.sort(key=lambda x: str(x.get("created_at", "")), reverse=True)

        # 3. Count unread notifications for the badge
        unread_count = sum(1 for n in notifications if not n.get("is_read", False))

        print(f"[NOTIF] Received in UI: {len(notifications)} notifications, {unread_count} unread")

        return {
            "userId": user_id,
            "notifications": notifications,
            "unreadCount": unread_count,
        }
    except Exception as e:
        print(f"[NOTIF] Error fetching notifications: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/read")
async def mark_as_read(request: MarkReadRequest):
    """Mark one or more notifications as read for a user."""
    try:
        print(f"[NOTIF] Marking as read: {len(request.notificationIds)} notifications")
        
        batch = db.batch()
        for notification_id in request.notificationIds:
            doc_ref = db.collection("notifications").document(notification_id)
            batch.update(doc_ref, {"is_read": True})
        
        batch.commit()
        print(f"[NOTIF] Marked as read successful")

        return {"message": f"{len(request.notificationIds)} notification(s) marked as read"}
    except Exception as e:
        print(f"[NOTIF] Error marking as read: {e}")
        raise HTTPException(status_code=500, detail=str(e))
