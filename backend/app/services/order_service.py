# app/services/order_service.py
# Order Management logic for the Swipify ecommerce platform.

import uuid
from datetime import datetime, timezone
from firebase_client import db
from app.models.order import (
    OrderCreateRequest,
    OrderItem,
    BuyNowRequest,
    OrderStatus,
    VALID_ORDER_TRANSITIONS,
)
from app.models.shipping import SelectedShippingOption
from app.utils.notifications import create_notification
from app.services.email_service import email_service
from fastapi import BackgroundTasks
from app.services.voucher_service import finalize_voucher_usage_service
from app.services.inventory_service import (
    batch_reserve_order_stock_service,
    batch_revert_order_stock_service
)
from app.services.easyship_service import create_easyship_shipment
from firebase_admin import firestore
from typing import Optional, List, Dict, Any

def get_current_time_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize_order_timestamps(order: dict) -> dict:
    for key in ("created_at", "updated_at"):
        val = order.get(key)
        if val is not None and not isinstance(val, str):
            try:
                order[key] = val.isoformat()
            except Exception:
                order[key] = str(val)
    return order


async def create_order_service(order_data: OrderCreateRequest) -> dict:
    """Business logic to create an order and clear the user's cart."""
    print(f"[ORDER] Creating order for user {order_data.user_id}, seller {order_data.seller_id}")

    try:
        if order_data.payment_method.lower() == "cod":
            pending_cod = db.collection("orders").where("user_id", "==", order_data.user_id).where("payment_method", "==", "cod").where("status", "==", "pending").get()
            if len(pending_cod) >= 3:
                raise ValueError("Anti-spam: Maximum of 3 pending COD orders reached.")

        # 1. RESERVE STOCK
        batch_reserve_order_stock_service(order_data.items)

        order_id = str(uuid.uuid4())
        now = get_current_time_iso()
        subtotal = order_data.total_price - (order_data.discount_amount or 0.0)
        shipping_fee = order_data.selected_shipping_option.fee
        total_order_price = round(subtotal + shipping_fee, 2)
        
        order_dict = {
            "id": order_id,
            "user_id": order_data.user_id,
            "seller_id": order_data.seller_id,
            "items": [item.dict() for item in order_data.items],
            "total_price": total_order_price,
            "discount_amount": order_data.discount_amount or 0.0,
            "voucher_id": order_data.voucher_id,
            "shipping_details": order_data.selected_shipping_option.dict(),
            "shipping_address": order_data.shipping_address.dict(),
            "logistic_provider": order_data.logistic_provider or "Standard Logistics",
            "tracking_number": None,
            "status": OrderStatus.PENDING.value,
            "payment_method": order_data.payment_method,
            "payment_status": "unpaid",
            "created_at": now,
            "updated_at": now,
            "status_history": [
                {
                    "timestamp": now,
                    "old_status": None,
                    "new_status": OrderStatus.PENDING.value,
                    "updated_by": "system",
                    "notes": "Order created",
                }
            ],
        }

        db.collection("orders").document(order_id).set(order_dict)

        if order_data.voucher_id:
            finalize_voucher_usage_service(order_data.user_id, order_data.voucher_id)

        # Background Task: Notification
        create_notification(
            order_data.seller_id,
            "New Order! 🛍️",
            f"New order (ID: {order_id[:8]}) for ₱{total_order_price:.2f}",
            "NEW_ORDER"
        )

        # Clear Cart
        cart_ref = db.collection("carts").document(order_data.user_id).collection("items")
        for item in order_data.items:
            cart_ref.document(item.product_id).delete()

        return order_dict

    except Exception as e:
        batch_revert_order_stock_service(order_data.items)
        print(f"[ORDER ERROR] {e}")
        raise e


async def buy_now_service(buy_request: BuyNowRequest) -> dict:
    """Business logic for Buy Now checkout."""
    try:
        # Reserve stock
        batch_reserve_order_stock_service([buy_request])

        product_doc = db.collection("products").document(buy_request.product_id).get()
        if not product_doc.exists: raise ValueError("Product not found")

        p_data = product_doc.to_dict()
        price = float(p_data.get("price", 0.0))
        seller_id = p_data.get("seller_id", "")
        
        subtotal = price * buy_request.quantity
        shipping_fee = buy_request.selected_shipping_option.fee
        total_price = round(subtotal + shipping_fee, 2)
        
        order_id = str(uuid.uuid4())
        now = get_current_time_iso()

        order_dict = {
            "id": order_id,
            "user_id": buy_request.user_id,
            "seller_id": seller_id,
            "items": [{
                "product_id": buy_request.product_id,
                "name": p_data.get("name"),
                "price": price,
                "quantity": buy_request.quantity,
                "image_url": p_data.get("images", [""])[0] if p_data.get("images") else "",
            }],
            "total_price": total_price,
            "shipping_details": buy_request.selected_shipping_option.dict(),
            "shipping_address": buy_request.shipping_address.dict(),
            "status": OrderStatus.PENDING.value,
            "payment_method": buy_request.payment_method,
            "payment_status": "unpaid",
            "created_at": now,
            "updated_at": now,
            "status_history": [{"timestamp": now, "new_status": OrderStatus.PENDING.value, "notes": "Buy Now order created"}]
        }

        db.collection("orders").document(order_id).set(order_dict)
        return order_dict
    except Exception as e:
        batch_revert_order_stock_service([buy_request])
        raise e


async def get_user_orders_service(user_id: str, limit: int = 10, last_doc_id: Optional[str] = None) -> list:
    """Fetch user orders with pagination."""
    query = db.collection("orders").where("user_id", "==", user_id).order_by("created_at", direction=firestore.Query.DESCENDING)
    
    if last_doc_id:
        last_doc = db.collection("orders").document(last_doc_id).get()
        if last_doc.exists:
            query = query.start_after(last_doc)

    docs = query.limit(limit).get()
    results = []
    for doc in docs:
        d = doc.to_dict()
        d["id"] = doc.id
        results.append(_normalize_order_timestamps(d))
    return results


async def get_seller_orders_service(seller_id: str, limit: int = 10, last_doc_id: Optional[str] = None) -> list:
    """Fetch seller orders with pagination."""
    query = db.collection("orders").where("seller_id", "==", seller_id).order_by("created_at", direction=firestore.Query.DESCENDING)
    
    if last_doc_id:
        last_doc = db.collection("orders").document(last_doc_id).get()
        if last_doc.exists:
            query = query.start_after(last_doc)

    docs = query.limit(limit).get()
    results = []
    for doc in docs:
        d = doc.to_dict()
        d["id"] = doc.id
        results.append(_normalize_order_timestamps(d))
    return results


async def calculate_seller_earnings_service(seller_id: str) -> dict:
    """Calculates seller metrics."""
    orders = db.collection("orders").where("seller_id", "==", seller_id).get()
    total_earnings = 0.0
    count = 0
    delivered = 0
    
    for doc in orders:
        data = doc.to_dict()
        count += 1
        if data.get("status") in [OrderStatus.DELIVERED.value, OrderStatus.COMPLETED.value]:
            total_earnings += float(data.get("total_price", 0.0))
            delivered += 1
            
    return {
        "total_earnings": round(total_earnings, 2),
        "total_orders": count,
        "delivered_count": delivered
    }


async def update_order_status_service(order_id: str, new_status: OrderStatus, background_tasks: BackgroundTasks) -> dict:
    """Update order status with async background tasks for Easyship and Email."""
    order_ref = db.collection("orders").document(order_id)
    snapshot = order_ref.get()
    if not snapshot.exists: raise ValueError("Order not found")
    
    order_data = snapshot.to_dict()
    current_status = OrderStatus(order_data.get("status"))

    if new_status not in VALID_ORDER_TRANSITIONS.get(current_status, set()):
        raise ValueError(f"Invalid transition from {current_status.value} to {new_status.value}")

    now = get_current_time_iso()
    update_data = {
        "status": new_status.value,
        "updated_at": now,
        "status_history": firestore.ArrayUnion([{
            "timestamp": now,
            "old_status": current_status.value,
            "new_status": new_status.value,
            "updated_by": "system"
        }])
    }

    # Logistics Logic
    if new_status == OrderStatus.READY_FOR_SHIPMENT:
        background_tasks.add_task(_handle_easyship_integration, order_id, order_data)

    # Revert Stock
    if new_status == OrderStatus.CANCELLED:
        batch_revert_order_stock_service([OrderItem(**i) for i in order_data.get("items", [])])

    order_ref.update(update_data)
    
    # Notifications & Emails
    background_tasks.add_task(_notify_status_change, order_data.get("user_id"), order_id, new_status.value)
    
    final = order_ref.get().to_dict()
    final["id"] = order_id
    return _normalize_order_timestamps(final)


async def _handle_easyship_integration(order_id: str, order_data: dict):
    """Background task for Easyship shipment creation."""
    try:
        seller_doc = db.collection("sellers").document(order_data["seller_id"]).get()
        if not seller_doc.exists: return

        seller_data = seller_doc.to_dict()
        shipping_addr = order_data.get("shipping_address", {})
        
        payload = {
            "order_id": order_id,
            "payment_method": order_data.get("payment_method"),
            "total_price": order_data.get("total_price"),
            "origin_address": {
                "line_1": seller_data.get("street", "Seller Street"),
                "city": seller_data.get("city", "Manila"),
                "state": seller_data.get("province", "Metro Manila"),
                "postal_code": seller_data.get("postal_code", "1000"),
                "country_alpha2": "PH",
                "contact_name": seller_data.get("store_name", "Swipify Seller"),
                "contact_phone": seller_data.get("phone_number", ""),
                "contact_email": "seller@swipify.com"
            },
            "destination_address": {
                "line_1": shipping_addr.get("street", ""),
                "city": shipping_addr.get("city", ""),
                "state": shipping_addr.get("region", ""),
                "postal_code": shipping_addr.get("postal_code", ""),
                "country_alpha2": "PH",
                "contact_name": shipping_addr.get("full_name", "Customer"),
                "contact_phone": shipping_addr.get("phone", ""),
                "contact_email": "customer@example.com"
            },
            "courier_id": order_data.get("shipping_details", {}).get("id", "standard"),
            "total_weight": sum(item.get("quantity", 1) * 0.5 for item in order_data.get("items", [])),
            "items": [{
                "description": i.get("name"),
                "sku": i.get("product_id"),
                "quantity": i.get("quantity"),
                "actual_weight": 0.5,
                "declared_currency": "PHP",
                "declared_customs_value": i.get("price")
            } for i in order_data.get("items", [])]
        }

        shipment = await create_easyship_shipment(payload)
        
        db.collection("orders").document(order_id).update({
            "tracking_number": shipment["tracking_number"],
            "logistic_provider": shipment["courier"],
            "label_url": shipment["label_url"],
            "shipment_id": shipment["shipment_id"],
            "status": OrderStatus.LABEL_CREATED.value
        })
        
        db.collection("shipments").document(shipment["shipment_id"]).set({
            "order_id": order_id,
            "tracking_number": shipment["tracking_number"],
            "status": "label_created",
            "courier": shipment["courier"],
            "label_url": shipment["label_url"],
            "created_at": get_current_time_iso()
        })
    except Exception as e:
        print(f"[EASYSHIP ERROR] {e}")
        db.collection("orders").document(order_id).update({"status": OrderStatus.EXCEPTION.value, "notes": f"Easyship Error: {str(e)}"})


async def _notify_status_change(user_id: str, order_id: str, status: str):
    """Background task for notifications and emails."""
    create_notification(user_id, f"Order Update: {status}", f"Order {order_id[:8]} is now {status}.", "ORDER_UPDATE")
    
    user_doc = db.collection("users").document(user_id).get()
    if user_doc.exists:
        email = user_doc.to_dict().get("email")
        if email:
            await email_service.send_order_status_email(email, order_id, status, None)


async def confirm_cod_service(order_id: str) -> dict:
    order_ref = db.collection("orders").document(order_id)
    snap = order_ref.get()
    if not snap.exists: raise ValueError("Order not found")
    
    order_ref.update({"is_cod_confirmed": True, "updated_at": get_current_time_iso()})
    return _normalize_order_timestamps(order_ref.get().to_dict())


async def get_order_by_id(order_id: str) -> dict:
    doc = db.collection("orders").document(order_id).get()
    if not doc.exists: raise ValueError("Order not found")
    order = doc.to_dict()
    order["id"] = doc.id
    return _normalize_order_timestamps(order)


def generate_seller_orders_csv_service(seller_id: str):
    import io, csv
    orders = db.collection("orders").where("seller_id", "==", seller_id).get()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Order ID", "Date", "Customer", "Total", "Status"])
    for doc in orders:
        o = doc.to_dict()
        writer.writerow([doc.id, o.get("created_at"), o.get("user_id"), o.get("total_price"), o.get("status")])
    return output.getvalue()
