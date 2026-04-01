# backend/app/utils/notifications.py
# Centralized utility for managing in-app notifications and push notifications via FCM.
# Debug logs follow [NOTIF] prefix convention.

from firebase_client import db
from firebase_admin import messaging
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from datetime import datetime
import uuid

def create_notification(user_id: str, title: str, message: str, notification_type: str):
    """Creates an in-app notification in Firestore and sends a push notification via FCM.
    
    Fields follow user request: user_id, title, message, type, is_read, created_at.
    """
    try:
        print(f"[NOTIF] Creating notification for user: {user_id}")
        
        notification_id = str(uuid.uuid4())
        notification_data = {
            "user_id": user_id,
            "title": title,
            "message": message,
            "type": notification_type,
            "is_read": False,
            "created_at": SERVER_TIMESTAMP
        }
        
        # 1. Store in Firestore
        db.collection("notifications").document(notification_id).set(notification_data)
        print(f"[NOTIF] In-app notification stored: {notification_id}")
        
        # 2. Attempt push notification if device token exists
        user_doc = db.collection("users").document(user_id).get()
        if user_doc.exists:
            user_data = user_doc.to_dict()
            token = user_data.get("device_token")
            
            if token:
                print(f"[NOTIF] Sending push notification to token: {token[:10]}...")
                message_payload = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=message,
                    ),
                    token=token,
                    data={
                        "click_action": "FLUTTER_NOTIFICATION_CLICK",
                        "type": notification_type,
                        "notification_id": notification_id
                    }
                )
                response = messaging.send(message_payload)
                print(f"[NOTIF] Push notification sent: {response}")
            else:
                print(f"[NOTIF] No device_token found for user {user_id}, skipping push")
        
        return True
    except Exception as e:
        print(f"[NOTIF] Error creating notification: {e}")
        return False

def broadcast_notification(title: str, message: str, notification_type: str):
    """Broadcasts a notification to all registered users."""
    try:
        print(f"[NOTIF] Broadcasting new product: {title}")
        
        # 1. Fetch all users
        users_docs = db.collection("users").get()
        count = 0
        
        # 2. Create in-app notifications for each (using batch for efficiency)
        batch = db.batch()
        for doc in users_docs:
            user_id = doc.id
            notif_id = str(uuid.uuid4())
            notif_ref = db.collection("notifications").document(notif_id)
            
            batch.set(notif_ref, {
                "user_id": user_id,
                "title": title,
                "message": message,
                "type": notification_type,
                "is_read": False,
                "created_at": SERVER_TIMESTAMP
            })
            count += 1
            
        batch.commit()
        print(f"[NOTIF] Users notified: {count}")
        
        # 3. Send FCM broadcast (via topic if enabled, or simple send)
        # Note: For real apps, use topics. Here we follow explicit 'broadcast' requirement.
        # We can send to a 'all_users' topic if users register for it.
        try:
            topic_message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=message,
                ),
                topic="all_users",
                data={
                    "type": notification_type
                }
            )
            messaging.send(topic_message)
            print(f"[NOTIF] Sending push notification (broadcast to topic 'all_users')")
        except Exception as push_err:
            print(f"[NOTIF] Broadcast push error (possibly topic not set): {push_err}")
            
        return count
    except Exception as e:
        print(f"[NOTIF] Error broadcasting: {e}")
        return 0
