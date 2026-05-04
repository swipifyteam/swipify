# backend/app/routes/chats.py
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from typing import Optional
from app.utils.cloudinary_handler import upload_media_to_cloudinary
from firebase_client import db
from firebase_admin import messaging
import uuid

router = APIRouter()

class ChatNotifyRequest(BaseModel):
    receiver_id: str
    sender_name: str
    message: str

@router.post("/upload-media")
async def upload_chat_media(file: UploadFile = File(...)):
    """Generic media upload to Cloudinary for Chat (images/videos). Returns the secure CDN URL."""
    try:
        print(f"[CHAT] Uploading media: {file.filename}")
        contents = await file.read()
        unique_filename = f"{uuid.uuid4()}_{file.filename}"
        url = upload_media_to_cloudinary(contents, unique_filename)
        return {"media_url": url}
    except Exception as e:
        print(f"[CHAT] Error uploading media: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/notify")
async def send_chat_notification(request: ChatNotifyRequest):
    """Triggers an FCM push notification to the receiver for a new chat message."""
    try:
        print(f"[CHAT] Sending notification to {request.receiver_id} from {request.sender_name}")
        
        user_doc = db.collection("users").document(request.receiver_id).get()
        if user_doc.exists:
            user_data = user_doc.to_dict()
            token = user_data.get("device_token")
            
            if token:
                message_payload = messaging.Message(
                    notification=messaging.Notification(
                        title=f"New Message from {request.sender_name}",
                        body=request.message,
                    ),
                    token=token,
                    data={
                        "click_action": "FLUTTER_NOTIFICATION_CLICK",
                        "type": "chat_message",
                    }
                )
                response = messaging.send(message_payload)
                print(f"[CHAT] Push notification sent: {response}")
                return {"success": True}
            else:
                print(f"[CHAT] No device_token found for user {request.receiver_id}, skipping push")
                return {"success": False, "reason": "No device token"}
        else:
            print(f"[CHAT] User {request.receiver_id} not found")
            return {"success": False, "reason": "User not found"}
            
    except Exception as e:
        print(f"[CHAT] Error sending notification: {e}")
        raise HTTPException(status_code=500, detail=str(e))
