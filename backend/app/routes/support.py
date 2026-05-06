from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Form, BackgroundTasks
from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from app.utils.cloudinary_handler import upload_image_to_cloudinary
import uuid
import json
from typing import List, Optional

from app.services.email_service import email_service

router = APIRouter()

@router.post("/tickets")
async def create_support_ticket(
    background_tasks: BackgroundTasks,
    user_id: str = Form(...),
    user_name: str = Form(...),
    user_email: str = Form(...),
    category: str = Form(...),
    subject: str = Form(...),
    message: str = Form(...),
    priority: str = Form("medium"),
    images: Optional[List[UploadFile]] = File(None)
):
    """Create a new support ticket with optional images."""
    try:
        image_urls = []
        if images:
            for image in images:
                contents = await image.read()
                unique_filename = f"support_{uuid.uuid4()}_{image.filename}"
                url = upload_image_to_cloudinary(contents, unique_filename)
                image_urls.append(url)
        
        ticket_data = {
            "user_id": user_id,
            "user_name": user_name,
            "user_email": user_email,
            "category": category,
            "subject": subject,
            "message": message,
            "priority": priority,
            "status": "pending",
            "images": image_urls,
            "created_at": SERVER_TIMESTAMP,
            "updated_at": SERVER_TIMESTAMP
        }
        
        doc_ref = db.collection("support_tickets").add(ticket_data)
        ticket_id = doc_ref[1].id

        # Send confirmation email
        background_tasks.add_task(email_service.send_support_ticket_email, user_email, ticket_id)
        
        return {"success": True, "ticket_id": ticket_id}
    except Exception as e:
        print(f"[SUPPORT ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/my-tickets/{user_id}")
async def get_my_tickets(user_id: str):
    """Fetch all tickets submitted by a specific user."""
    try:
        # [INDEX FIX] Remove order_by from query to avoid 400 error while index is building
        docs = db.collection("support_tickets").where("user_id", "==", user_id).get()
        tickets = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            # Handle timestamp
            if data.get("created_at") and hasattr(data["created_at"], "isoformat"):
                data["created_at"] = data["created_at"].isoformat()
            tickets.append(data)
        
        # Sort in memory by created_at DESC (newest first)
        tickets.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        
        return tickets
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
