# app/services/order_service.py
# Order Management logic for the Swipify ecommerce platform.
# Generates unique orders, groups by seller, and handles cart clearing.

import uuid
from datetime import datetime, timezone
from firebase_client import db
from app.models.order import (
    OrderCreateRequest,
    OrderItem,
    BuyNowRequest,
    OrderStatus,  # Import OrderStatus
    VALID_ORDER_TRANSITIONS,  # Import VALID_ORDER_TRANSITIONS
)
from app.models.shipping import SelectedShippingOption
from app.utils.notifications import create_notification
from app.services.voucher_service import increment_voucher_usage_service


def get_current_time_iso() -> str:
    """Utility to get the current timestamp in ISO 8601 format."""
    return datetime.now(timezone.utc).isoformat()


def create_order_service(order_data: OrderCreateRequest) -> dict:
    """Business logic to create an order and clear the user's cart.

    Ensures each order has its own unique ID to prevent overwriting.
    """
    print(
        f"[ORDER] Creating order for user {order_data.user_id}, seller {order_data.seller_id}"
    )

    try:
        # 1. Generate a NEW, UNIQUE UUID for this specific order
        # THIS PREVENTS OVERWRITING — always use uuid4
        order_id = str(uuid.uuid4())

        now = get_current_time_iso()

        subtotal = order_data.total_price - (order_data.discount_amount or 0.0)
        
        distance_km = 5.0 # MOCK distance
        weight_kg = sum([item.quantity * 0.5 for item in order_data.items])
        shipping_fee = 40.0 + (8.0 * distance_km) + (5.0 * weight_kg)
        if shipping_fee < 120.0:
            shipping_fee = 120.0
        if shipping_fee > 250.0:
            shipping_fee = 250.0
            
        shipping_fee = round(shipping_fee, 2)
        total_order_price = round(subtotal + shipping_fee, 2)
        
        # Override the fee inside the snapshot so UI matches history
        order_data.selected_shipping_option.fee = shipping_fee

        # 2. Build the order dictionary
        # Explicit naming: seller_id and status mapping
        order_dict = {
            "id": order_id,
            "user_id": order_data.user_id,
            "seller_id": order_data.seller_id,
            "items": [item.dict() for item in order_data.items],
            "total_price": total_order_price,
            "discount_amount": order_data.discount_amount or 0.0,
            "voucher_id": order_data.voucher_id,
            "shipping_details": order_data.selected_shipping_option.dict(),  # Snapshot shipping details
            "shipping_address": order_data.shipping_address.dict(),  # Snapshot address
            "logistic_provider": order_data.logistic_provider or "Standard Logistics",
            "tracking_number": None,
            "status": OrderStatus.PENDING.value,  # Initial status (starts pending)
            "payment_status": "unpaid",  # Payment pending
            "created_at": now,
            "updated_at": now,
        }

        # 3. Write specifically to the 'orders' collection (unique ID)
        db.collection("orders").document(order_id).set(order_dict)
        print(f"[ORDER CREATED] Success: ID={order_id}")

        # Increment Voucher Usage if present
        if order_data.voucher_id:
            increment_voucher_usage_service(order_data.voucher_id)

        # Log initial status
        db.collection("orders").document(order_id).collection("status_history").add(
            {
                "timestamp": now,
                "old_status": None,
                "new_status": OrderStatus.PENDING.value,
                "updated_by": "system",
                "notes": "Order created",
            }
        )

        # 🚨 NOTIFICATION: Notify Seller 🚨
        create_notification(
            order_data.seller_id,
            "New Order! 🛍️",
            f"You have a new order (ID: {order_id[:8]}) for ₱{order_dict['total_price']:.2f}",
            "NEW_ORDER"
        )

        # 🚨 PART 5 FIX: CLEAR THE CART AFTER CHECKOUT 🚨
        # We delete all items from this user's cart sub-collection
        # This keeps the UI clean and prevents double ordering the same items
        try:
            cart_ref = (
                db.collection("carts").document(order_data.user_id).collection("items")
            )
            cart_docs = cart_ref.get()

            # Batch delete would be more efficient, but manual delete is fine for typical cart sizes
            for doc in cart_docs:
                # OPTIONAL: ONLY remove the items that were actually ordered
                # For simplicity here, we assume a total checkout (full cart)
                doc.reference.delete()

            print(f"[CART CLEARED] Successfully removed cart items for user {order_data.user_id}")
        except Exception as cart_err:
            print(f"[CART CLEANUP ERROR] Non-fatal, but could not clear cart: {cart_err}")

        return order_dict

    except Exception as e:
        print(f"[ORDER ERROR] Failed: {str(e)}")
        raise e


def buy_now_service(buy_request: BuyNowRequest) -> dict:
    """Business logic for Buy Now checkout (creates an order instantly without cart)."""
    print(
        f"[BUY NOW] Processing for user {buy_request.user_id}, product {buy_request.product_id}"
    )

    try:
        # 1. Fetch the product details to get exact pricing and seller
        product_ref = db.collection("products").document(buy_request.product_id)
        product_doc = product_ref.get()
        if not product_doc.exists:
            raise ValueError(f"Product {buy_request.product_id} not found")

        product_data = product_doc.to_dict()
        price = float(product_data.get("price", 0.0))
        seller_id = product_data.get("seller_id", "")
        name = product_data.get("name", "Unknown Product")

        subtotal = price * buy_request.quantity
        distance_km = 5.0 # MOCK distance
        weight_kg = buy_request.quantity * 0.5
        shipping_fee = 40.0 + (8.0 * distance_km) + (5.0 * weight_kg)
        if shipping_fee < 120.0:
            shipping_fee = 120.0
        if shipping_fee > 250.0:
            shipping_fee = 250.0
            
        shipping_fee = round(shipping_fee, 2)
        total_price = round(subtotal + shipping_fee, 2)
        
        buy_request.selected_shipping_option.fee = shipping_fee

        order_id = str(uuid.uuid4())
        now = get_current_time_iso()

        # 3. Build identical order dictionary structure
        order_dict = {
            "id": order_id,
            "user_id": buy_request.user_id,
            "seller_id": seller_id,
            "items": [
                {
                    "product_id": buy_request.product_id,
                    "name": name,
                    "price": price,
                    "quantity": buy_request.quantity,
                    "image_url": product_data.get("images", [""])[0] if product_data.get("images") else "",
                }
            ],
            "total_price": total_price,
            "shipping_details": buy_request.selected_shipping_option.dict(),  # Snapshot shipping details
            "shipping_address": buy_request.shipping_address.dict(),  # Snapshot address
            "logistic_provider": "Standard Logistics",
            "tracking_number": None,
            "status": OrderStatus.PENDING.value,
            "payment_status": "unpaid",
            "created_at": now,
            "updated_at": now,
        }

        # 4. Write to orders collection
        db.collection("orders").document(order_id).set(order_dict)
        print("[BUY NOW ORDER CREATED]", order_dict)

        # Log initial status
        db.collection("orders").document(order_id).collection("status_history").add(
            {
                "timestamp": now,
                "old_status": None,
                "new_status": OrderStatus.PENDING.value,
                "updated_by": "system",
                "notes": "Buy Now order created",
            }
        )

        return order_dict

    except Exception as e:
        print(f"[BUY NOW ERROR] Failed: {str(e)}")
        raise e


def get_user_orders_service(user_id: str) -> list:
    """Fetch all orders for a specific user, sorted by date."""
    try:
        docs = db.collection("orders").where("user_id", "==", user_id).get()
        orders = []
        for doc in docs:
            order = doc.to_dict()
            order["id"] = doc.id
            orders.append(order)

        # Reverse chronological order (simple list sort)
        orders.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return orders
    except Exception as e:
        print(f"[GET USER ORDERS ERROR] {str(e)}")
        raise e


def get_seller_orders_service(seller_id: str) -> list:
    """Fetch all orders for a specific seller/shop."""
    try:
        docs = db.collection("orders").where("seller_id", "==", seller_id).get()
        orders = []
        for doc in docs:
            order = doc.to_dict()
            order["id"] = doc.id
            orders.append(order)

        orders.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return orders
    except Exception as e:
        print(f"[GET SELLER ORDERS ERROR] {str(e)}")
        raise e


def calculate_seller_earnings_service(seller_id: str) -> dict:
    """
    🚨 PART 7 FIX: SELLER EARNINGS (REAL CALCULATION) 🚨
    Calculates total earnings only from 'delivered' orders.
    Also returns a count of all current orders for the dashboard.
    """
    try:
        docs = db.collection("orders").where("seller_id", "==", seller_id).get()
        total_earnings = 0.0
        total_orders_count = 0
        delivered_count = 0

        for doc in docs:
            order = doc.to_dict()
            total_orders_count += 1

            # Sum up only orders marked as 'delivered' (real money)
            # Case insensitive check
            status = order.get("status", "").lower()
            if status == OrderStatus.DELIVERED.value:
                total_earnings += float(order.get("total_price", 0.0))
                delivered_count += 1

        print(
            f"[EARNINGS CALCULATED] Seller={seller_id}, Total={total_earnings}, Delivered Order Count={delivered_count}"
        )
        return {
            "total_earnings": total_earnings,
            "total_orders": total_orders_count,
            "delivered_count": delivered_count,
        }
    except Exception as e:
        print(f"[EARNINGS ERROR] {str(e)}")
        return {"total_earnings": 0.0, "total_orders": 0, "delivered_count": 0}


def update_order_status_service(order_id: str, new_status: OrderStatus) -> dict:
    """Safely update order status with logging and transition validation."""
    try:
        order_ref = db.collection("orders").document(order_id)
        order_doc = order_ref.get()
        if not order_doc.exists:
            raise ValueError(f"Order {order_id} not found")

        current_status = OrderStatus(order_doc.get("status"))

        # Validate transition
        if new_status not in VALID_ORDER_TRANSITIONS.get(
            current_status, set()
        ):
            raise ValueError(
                f"Invalid order status transition from {current_status.value} to {new_status.value}"
            )

        now = get_current_time_iso()
        
        # 🚨 LOGISTICS INJECTION: Generate tracking number if SHIPPED 🚨
        update_data = {"status": new_status.value, "updated_at": now}
        if new_status == OrderStatus.SHIPPED:
            # Generate a cool-looking tracking ID (e.g., SW-12345678)
            tracking_id = f"SW-{str(uuid.uuid4())[:8].upper()}"
            update_data["tracking_number"] = tracking_id
            update_data["logistic_provider"] = "Swipify Express"

        # Update order status
        order_ref.update(update_data)

        # Log status transition
        db.collection("orders").document(order_id).collection("status_history").add(
            {
                "timestamp": now,
                "old_status": current_status.value,
                "new_status": new_status.value,
                "updated_by": "system",  # Assuming system updates, could be user_id from auth context
            }
        )

        # 🚨 NOTIFICATION: Notify Buyer of status change 🚨
        buyer_id = order_doc.get("user_id")
        buyer_titles = {
            OrderStatus.PROCESSING.value: "Order Processing 📦",
            OrderStatus.SHIPPED.value: "Order Shipped 🚚",
            OrderStatus.DELIVERED.value: "Order Delivered 🎁",
            OrderStatus.CANCELLED.value: "Order Cancelled ❌",
        }
        if new_status.value in buyer_titles:
            msg = f"Your order {order_id[:8]} is now {new_status.value}."
            if new_status == OrderStatus.SHIPPED:
                msg += f" Tracking: {update_data.get('tracking_number')}"
            create_notification(buyer_id, buyer_titles[new_status.value], msg, "ORDER_UPDATE")

        final_doc = order_ref.get().to_dict()
        final_doc["id"] = order_id
        return final_doc
    except Exception as e:
        print(f"[UPDATE STATUS ERROR] {str(e)}")
        raise e


def update_order_payment_service(order_id: str, new_payment_status: str) -> dict:
    """Update order payment status (unpaid, paid, failed)."""
    try:
        order_ref = db.collection("orders").document(order_id)
        order_doc = order_ref.get()
        if not order_doc.exists:
            raise ValueError(f"Order {order_id} not found")

        order_ref.update(
            {"payment_status": new_payment_status, "updated_at": get_current_time_iso()}
        )

        final_doc = order_ref.get().to_dict()
        final_doc["id"] = order_id
        return final_doc
    except Exception as e:
        print(f"[UPDATE PAYMENT ERROR] {str(e)}")
        raise e
