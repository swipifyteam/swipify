# app/routes/vouchers.py
# Voucher API endpoints for the Swipify ecommerce platform.
# Handles fetching active vouchers and claiming them (creates claimedVouchers + notification).

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
import uuid

router = APIRouter()


class ClaimVoucherRequest(BaseModel):
    """Request body for claiming a voucher."""
    userId: str
    voucherId: str


@router.get("")
async def get_vouchers():
    """Fetch all available vouchers from Firestore."""
    try:
        docs = db.collection("vouchers").get()
        vouchers = []
        for doc in docs:
            voucher = doc.to_dict()
            voucher["id"] = doc.id
            vouchers.append(voucher)
        return {"vouchers": vouchers}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/claim")
async def claim_voucher(request: ClaimVoucherRequest):
    """Claim a voucher for a user.
    
    Prevents duplicate claims — a userId + voucherId pair can only be claimed once.
    On success, creates a claimedVoucher document AND a notification for the user.
    """
    try:
        # Check if this user has already claimed this voucher
        existing = (
            db.collection("claimedVouchers")
            .where("userId", "==", request.userId)
            .where("voucherId", "==", request.voucherId)
            .limit(1)
            .get()
        )

        if len(existing) > 0:
            raise HTTPException(
                status_code=400,
                detail="You have already claimed this voucher"
            )

        # Fetch the voucher to get its title for the notification
        voucher_doc = db.collection("vouchers").document(request.voucherId).get()
        if not voucher_doc.exists:
            raise HTTPException(status_code=404, detail="Voucher not found")

        voucher = voucher_doc.to_dict()
        claim_id = str(uuid.uuid4())

        # Create the claimedVoucher document
        db.collection("claimedVouchers").document(claim_id).set({
            "userId": request.userId,
            "voucherId": request.voucherId,
            "claimedAt": SERVER_TIMESTAMP,
            "used": False,
        })

        # Create a notification to inform the user about their claimed voucher
        notification_id = str(uuid.uuid4())
        db.collection("notifications").document(notification_id).set({
            "userId": request.userId,
            "title": "🎟️ Voucher Claimed!",
            "message": f"You have successfully claimed: {voucher.get('title', 'a voucher')}. Use it at checkout!",
            "isRead": False,
            "createdAt": SERVER_TIMESTAMP,
        })

        return {
            "message": "Voucher claimed successfully!",
            "claimId": claim_id,
            "notificationId": notification_id,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
