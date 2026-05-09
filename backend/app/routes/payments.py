from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import List, Optional
from app.services.payment_service import PaymentService
from app.services.order_service import create_order_service
from app.models.order import OrderCreateRequest, OrderItem, OrderStatus, AddressSnapshot
from app.models.shipping import SelectedShippingOption
from app.utils.auth_utils import get_current_user
from firebase_client import db
from google.cloud import firestore

router = APIRouter()


# ── Request Models ───────────────────────────────────────────────────────────

class CheckoutItem(BaseModel):
    product_id: str
    name: str
    price: float
    quantity: int
    image_url: Optional[str] = None

class SellerGroup(BaseModel):
    seller_id: str
    items: List[CheckoutItem]
    total_price: float
    discount_amount: Optional[float] = 0.0
    voucher_id: Optional[str] = None

class PaymentCreateRequest(BaseModel):
    """Accepts full checkout data so orders are only created after payment."""
    seller_groups: List[SellerGroup]
    amount: float
    payment_method: str = "gcash"
    shipping_option: dict          # SelectedShippingOption as dict
    shipping_address: dict         # AddressSnapshot as dict


# ── Create Payment Session ───────────────────────────────────────────────────

@router.post("/create")
async def create_payment_session(request: PaymentCreateRequest, token: dict = Depends(get_current_user)):
    """
    Creates a PayMongo checkout session and saves the full checkout session data.
    Orders are NOT created here — they are created by the webhook on checkout_session.payment_paid.
    """
    user_id = token["uid"]
    try:
        if not request.seller_groups:
            raise HTTPException(status_code=400, detail="No items provided")

        # Basic amount validation (simplified)
        items_subtotal = sum(sg.total_price for sg in request.seller_groups)
        total_discounts = sum(sg.discount_amount or 0.0 for sg in request.seller_groups)
        shipping_fee = request.shipping_option.get('fee', 0.0)
        total_calculated = (items_subtotal + shipping_fee) - total_discounts
        
        actual_diff = abs(round(total_calculated, 2) - round(request.amount, 2))
        if actual_diff > 1.0: # Epsilon for rounding
             raise HTTPException(status_code=400, detail=f"Amount mismatch. Expected approx {total_calculated}, got {request.amount}")

        # Create PayMongo checkout session
        source_data = await PaymentService.create_checkout_session(request.amount, request.payment_method)

        # Save the full checkout session to Firestore
        session_id = source_data["id"]
        session_doc = {
            "session_id": session_id,
            "user_id": user_id,
            "amount": request.amount,
            "payment_method": request.payment_method,
            "status": "pending",
            "seller_groups": [sg.model_dump() for sg in request.seller_groups],
            "shipping_option": request.shipping_option,
            "shipping_address": request.shipping_address,
            "created_at": firestore.SERVER_TIMESTAMP,
        }
        db.collection("payment_sessions").document(session_id).set(session_doc)
        print(f"[PAYMENT] Session saved: {session_id} for user {user_id}")

        return source_data

    except Exception as e:
        print(f"[PAYMENT CREATE ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ── Webhook ──────────────────────────────────────────────────────────────────

@router.post("/webhook")
async def paymongo_webhook(request: Request):
    """
    Handles PayMongo webhooks with ATOMIC IDEMPOTENCY check.
    Uses Firestore transaction to prevent duplicate order creation.
    """
    raw_body = await request.body()
    signature_header = request.headers.get("paymongo-signature", "")

    if not PaymentService.verify_webhook_signature(raw_body, signature_header):
        raise HTTPException(status_code=401, detail="Invalid webhook signature")

    try:
        payload = await request.json()
        event_data = payload.get("data", {})
        event_type = event_data.get("attributes", {}).get("type")
        resource_data = event_data.get("attributes", {}).get("data", {})
        resource_id = resource_data.get("id")

        if not resource_id: return {"status": "ignored"}

        # ATOMIC IDEMPOTENCY LOCK
        transaction = db.transaction()
        
        @firestore.transactional
        def lock_and_get_session(tx, res_id):
            doc_ref = db.collection("payment_sessions").document(res_id)
            snap = doc_ref.get(transaction=tx)
            if not snap.exists:
                return None
            
            data = snap.to_dict()
            if data.get("status") in ["paid", "processing"]:
                return "ALREADY_PROCESSED"
            
            # Lock it
            tx.update(doc_ref, {"status": "processing", "updated_at": firestore.SERVER_TIMESTAMP})
            return data

        session_data = lock_and_get_session(transaction, resource_id)

        if not session_data:
            print(f"[WEBHOOK] Session not found: {resource_id}")
            return {"status": "ignored"}
            
        if session_data == "ALREADY_PROCESSED":
            print(f"[WEBHOOK] Session {resource_id} already processed. Skipping.")
            return {"status": "success", "message": "already processed"}

        if event_type in ["checkout_session.payment_paid", "payment.paid"]:
            created_order_ids = []
            for sg in session_data.get("seller_groups", []):
                order_request = OrderCreateRequest(
                    user_id=session_data["user_id"],
                    seller_id=sg["seller_id"],
                    items=[OrderItem(**item) for item in sg["items"]],
                    total_price=sg["total_price"],
                    discount_amount=sg.get("discount_amount", 0.0),
                    voucher_id=sg.get("voucher_id"),
                    selected_shipping_option=SelectedShippingOption(**session_data["shipping_option"]),
                    shipping_address=AddressSnapshot(**session_data["shipping_address"]),
                    payment_method="online",
                )
                
                # Await the async order creation
                order = await create_order_service(order_request)
                order_id = order["id"]
                created_order_ids.append(order_id)

                # Mark order as paid and processing
                db.collection("orders").document(order_id).update({
                    "payment_status": "paid",
                    "status": OrderStatus.PROCESSING.value,
                    "updated_at": firestore.SERVER_TIMESTAMP
                })

            # Final success state
            db.collection("payment_sessions").document(resource_id).update({
                "status": "paid",
                "order_ids": created_order_ids,
                "paid_at": firestore.SERVER_TIMESTAMP
            })
            print(f"[WEBHOOK] Payment success: {resource_id}. Orders: {created_order_ids}")

        elif event_type == "payment.failed":
            db.collection("payment_sessions").document(resource_id).update({
                "status": "failed",
                "updated_at": firestore.SERVER_TIMESTAMP
            })
            print(f"[WEBHOOK] Payment failed: {resource_id}")

        return {"status": "success"}
    except Exception as e:
        print(f"[WEBHOOK ERROR] {e}")
        # If order creation fails, status remains 'processing' or we can set it to 'error'
        try:
            db.collection("payment_sessions").document(resource_id).update({"status": "error", "error_log": str(e)})
        except: pass
        raise HTTPException(status_code=500, detail=str(e))
