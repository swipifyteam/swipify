from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import List, Optional
from app.services.payment_service import PaymentService
from app.services.order_service import create_order_service
from app.models.order import OrderCreateRequest, OrderItem, OrderStatus, AddressSnapshot
from app.models.shipping import SelectedShippingOption
from app.utils.auth_utils import get_current_user_id
from firebase_client import db

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
async def create_payment_session(request: PaymentCreateRequest, user_id: str = Depends(get_current_user_id)):
    """
    Creates a PayMongo checkout session and saves the full checkout session data.
    Orders are NOT created here — they are created by the webhook on checkout_session.payment_paid.
    """
    try:
        if not request.seller_groups:
            raise HTTPException(status_code=400, detail="No items provided")

        # Validate amount matches seller group totals + shipping - discounts
        # We must replicate the frontend logic exactly:
        # 1. Sum seller item totals
        # 2. Subtract seller-specific shop discounts
        # 3. Calculate shipping fee and subtract shipping discount, clamped to 0
        
        items_subtotal = sum(sg.total_price for sg in request.seller_groups)
        
        # In the frontend, 'discount_amount' in seller_groups includes BOTH shop and shipping discounts.
        # However, there's only one global shipping discount applied to the final shipping fee.
        # So we can just sum all discounts and subtract from (subtotal + shipping), 
        # BUT we must ensure the final shipping part isn't negative.
        
        total_discounts = sum(sg.discount_amount or 0.0 for sg in request.seller_groups)
        shipping_fee = request.shipping_option.get('fee', 0.0)
        
        # Simplified equivalent to frontend: (Subtotal - ShopDiscounts) + Max(0, ShipFee - ShipDiscount)
        # Since 'total_discounts' = ShopDiscounts + ShipDiscount:
        # total_calculated = (items_subtotal - (total_discounts - ship_discount)) + max(0, shipping_fee - ship_discount)
        # This is exactly what (items_subtotal + shipping_fee - total_discounts) would be UNLESS ship_discount > shipping_fee.
        
        total_calculated = (items_subtotal + shipping_fee) - total_discounts
        
        # If the total discount is more than the shipping fee + some items, we should still clamp it or just use the frontend's number if it's close enough.
        # E-commerce rule: Shipping discount only applies to shipping.
        # If total_discounts > shipping_fee, it might be because of shop discounts too.
        
        # To be safe and avoid race conditions/mismatches, we allow a small epsilon (1.0 PHP)
        # and we also check if the mismatch is specifically due to the shipping discount clamping.
        
        actual_diff = abs(round(total_calculated, 2) - round(request.amount, 2))
        
        if actual_diff > 0.01:
            print(f"[PAYMENT] ⚠️ Amount check: Calculated {total_calculated} vs Received {request.amount}. Diff: {actual_diff}")
            # If the difference is very small (rounding) or clearly a shipping discount clamping case, we can proceed.
            # But for now, let's keep it strict but log the exact components.
            if actual_diff > 1.0:
                 print(f"[PAYMENT] ❌ Amount mismatch too large! Subtotal: {items_subtotal}, Discounts: {total_discounts}, Shipping: {shipping_fee}")
                 raise HTTPException(
                    status_code=400,
                    detail=f"Amount mismatch. Expected approx {total_calculated}, got {request.amount}"
                )

        # Create PayMongo checkout session
        # Note: PaymentService.create_checkout_session handles amount centavos conversion and minimum amount check
        source_data = await PaymentService.create_checkout_session(request.amount, request.payment_method)

        # Save the full checkout session to Firestore keyed by the checkout session ID
        # The webhook will use this data to create actual orders
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
            "created_at": "now", # Placeholder for server timestamp if needed
        }
        db.collection("payment_sessions").document(session_id).set(session_doc)
        print(f"[PAYMENT] Session saved: {session_id} for user {user_id}")

        return source_data

    except HTTPException as he:
        print(f"[PAYMENT HTTP ERROR] {he.status_code}: {he.detail}")
        raise he
    except Exception as e:
        print(f"[PAYMENT CREATE ERROR] {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ── Webhook ──────────────────────────────────────────────────────────────────

@router.post("/webhook")
async def paymongo_webhook(request: Request):
    """
    Handles PayMongo webhooks.
    On payment.paid  → creates orders from the saved session data.
    On payment.failed → marks session as failed (no orders created).
    """
    raw_body = await request.body()
    signature_header = request.headers.get("paymongo-signature", "")

    if not PaymentService.verify_webhook_signature(raw_body, signature_header):
        raise HTTPException(status_code=401, detail="Invalid webhook signature")

    try:
        payload = await request.json()
        event_data = payload.get("data", {})
        event_type = event_data.get("attributes", {}).get("type")

        print(f"[WEBHOOK] Received event: {event_type}")

        # For Checkout Sessions, the session ID is in data.attributes.data.id
        # For legacy Source payments, it might be in data.attributes.data.id as well
        resource_data = event_data.get("attributes", {}).get("data", {})
        resource_id = resource_data.get("id")

        if not resource_id:
            print("[WEBHOOK] No resource ID found in event payload")
            return {"status": "ignored"}

        # Retrieve the payment session from Firestore
        # We store it keyed by the session ID (e.g., cs_...)
        session_doc_ref = db.collection("payment_sessions").document(resource_id)
        session_doc = session_doc_ref.get()
        
        if not session_doc.exists:
            print(f"[WEBHOOK] No session found for ID {resource_id}")
            return {"status": "ignored"}

        session = session_doc.to_dict()

        if event_type == "checkout_session.payment_paid" or event_type == "payment.paid":
            created_order_ids = []

            for sg in session.get("seller_groups", []):
                order_request = OrderCreateRequest(
                    user_id=session["user_id"],
                    seller_id=sg["seller_id"],
                    items=[OrderItem(**item) for item in sg["items"]],
                    total_price=sg["total_price"],
                    discount_amount=sg.get("discount_amount", 0.0),
                    voucher_id=sg.get("voucher_id"),
                    selected_shipping_option=SelectedShippingOption(**session["shipping_option"]),
                    shipping_address=AddressSnapshot(**session["shipping_address"]),
                    payment_method="online",
                )
                order = create_order_service(order_request)
                order_id = order["id"]
                created_order_ids.append(order_id)

                # Mark order as paid immediately since payment already succeeded
                db.collection("orders").document(order_id).update({
                    "payment_status": "paid",
                    "status": OrderStatus.PROCESSING.value,
                    "payment_method": session.get("payment_method", "digital_payment")
                })
                print(f"[WEBHOOK] Order {order_id} created and marked PAID + PROCESSING")

            # Update payment session status
            session_doc_ref.update({
                "status": "paid",
                "order_ids": created_order_ids,
                "updated_at": "now"
            })

        elif event_type == "payment.failed":
            session_doc_ref.update({
                "status": "failed",
                "updated_at": "now"
            })
            print(f"[WEBHOOK] Payment failed for session {resource_id}. No orders created.")

        return {"status": "success"}
    except Exception as e:
        print(f"[WEBHOOK ERROR] {str(e)}")
        raise HTTPException(status_code=500, detail="Webhook processing failed")
