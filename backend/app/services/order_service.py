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
from app.utils.email_service import send_order_status_email
from app.services.voucher_service import increment_voucher_usage_service
from app.services.inventory_service import (
    batch_reserve_order_stock_service,
    batch_revert_order_stock_service
)
from app.services.easyship_service import create_easyship_shipment
from firebase_admin import firestore

def get_current_time_iso() -> str:
    """Utility to get the current timestamp in ISO 8601 format."""
    return datetime.now(timezone.utc).isoformat()


def _normalize_order_timestamps(order: dict) -> dict:
    """Convert any Firestore DatetimeWithNanoseconds fields to ISO strings.

    Firestore can return native datetime objects when SERVER_TIMESTAMP is used.
    Pydantic's OrderResponse expects str for created_at / updated_at.
    """
    for key in ("created_at", "updated_at"):
        val = order.get(key)
        if val is not None and not isinstance(val, str):
            try:
                order[key] = val.isoformat()
            except Exception:
                order[key] = str(val)
    return order


def create_order_service(order_data: OrderCreateRequest) -> dict:
    """Business logic to create an order and clear the user's cart.

    Ensures each order has its own unique ID to prevent overwriting.
    """
    print(
        f"[ORDER] Creating order for user {order_data.user_id}, seller {order_data.seller_id}"
    )

    try:
        if order_data.payment_method.lower() == "cod":
            pending_cod = db.collection("orders").where("user_id", "==", order_data.user_id).where("payment_method", "==", "cod").where("status", "==", "pending").get()
            if len(pending_cod) >= 3:
                raise ValueError("Anti-spam: You have reached the maximum of 3 pending COD orders.")

        # 1. RESERVE STOCK FIRST
        # Will throw ValueError if stock is insufficient
        batch_reserve_order_stock_service(order_data.items)

        # 2. Generate a NEW, UNIQUE UUID for this specific order
        # THIS PREVENTS OVERWRITING — always use uuid4
        order_id = str(uuid.uuid4())

        now = get_current_time_iso()

        subtotal = order_data.total_price - (order_data.discount_amount or 0.0)
        
        # Use the provided shipping fee from the selection (passed from frontend/payment session)
        # If it's 0.0 and we want to allow it, that's fine.
        shipping_fee = order_data.selected_shipping_option.fee
        
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
            "payment_method": order_data.payment_method,
            "payment_status": "unpaid",  # Payment pending
            "is_cod_confirmed": False,
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

        # 🚨 PART 5 FIX: CLEAR THE CART FOR ORDERED ITEMS ONLY 🚨
        try:
            cart_ref = db.collection("carts").document(order_data.user_id).collection("items")
            ordered_product_ids = [item.product_id for item in order_data.items]
            
            for product_id in ordered_product_ids:
                cart_ref.document(product_id).delete()

            print(f"[CART CLEANUP] Removed {len(ordered_product_ids)} items for user {order_data.user_id}")
        except Exception as cart_err:
            print(f"[CART CLEANUP ERROR] Non-fatal: {cart_err}")

        return order_dict

    except Exception as e:
        # Revert stock if order creation completely fails after reservation
        try:
            batch_revert_order_stock_service(order_data.items)
        except Exception:
            pass
        print(f"[ORDER ERROR] Failed: {str(e)}")
        raise e


def buy_now_service(buy_request: BuyNowRequest) -> dict:
    """Business logic for Buy Now checkout (creates an order instantly without cart)."""
    print(
        f"[BUY NOW] Processing for user {buy_request.user_id}, product {buy_request.product_id}"
    )

    try:
        if buy_request.payment_method.lower() == "cod":
            pending_cod = db.collection("orders").where("user_id", "==", buy_request.user_id).where("payment_method", "==", "cod").where("status", "==", "pending").get()
            if len(pending_cod) >= 3:
                raise ValueError("Anti-spam: You have reached the maximum of 3 pending COD orders.")

        # 0. RESERVE STOCK FIRST
        batch_reserve_order_stock_service([buy_request])

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
            "payment_method": buy_request.payment_method,
            "payment_status": "unpaid",
            "is_cod_confirmed": False,
            "created_at": now,
            "updated_at": now,
            "status_history": [
                {
                    "timestamp": now,
                    "old_status": None,
                    "new_status": OrderStatus.PENDING.value,
                    "updated_by": "system",
                    "notes": "Buy Now order created",
                }
            ],
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
        try:
            batch_revert_order_stock_service([buy_request])
        except Exception:
            pass
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
            _normalize_order_timestamps(order)
            orders.append(order)

        # Reverse chronological order (simple list sort)
        orders.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)
        return orders
    except Exception as e:
        print(f"[GET USER ORDERS ERROR] {str(e)}")
        raise e


def get_seller_orders_service(seller_id: str) -> list:
    """Fetch all orders for a specific seller/shop."""
    try:
        # Fetch using seller_id
        docs_seller = db.collection("orders").where("seller_id", "==", seller_id).get()

        order_map = {}

        for doc in docs_seller:
            order = doc.to_dict()
            order["id"] = doc.id
            _normalize_order_timestamps(order)
            order_map[doc.id] = order

        orders = list(order_map.values())
        orders.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)
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
        orders = get_seller_orders_service(seller_id)
        total_earnings = 0.0
        total_orders_count = 0
        delivered_count = 0

        for order in orders:
            total_orders_count += 1

            # Sum up only orders marked as 'delivered' or 'completed' (real money)
            status = order.get("status", "").lower()
            if status in [OrderStatus.DELIVERED.value, OrderStatus.COMPLETED.value]:
                total_earnings += float(order.get("total_price", 0.0))
                delivered_count += 1

        print(
            f"[EARNINGS CALCULATED] Seller={seller_id}, Total={total_earnings}, Delivered/Completed Order Count={delivered_count}"
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

        # 🚨 PAYMENT LOCK VALIDATION 🚨
        if new_status == OrderStatus.PROCESSING:
            payment_method = order_doc.get("payment_method", "online").lower()
            payment_status = order_doc.get("payment_status", "unpaid").lower()
            is_cod_confirmed = order_doc.get("is_cod_confirmed", False)
            
            if payment_method == "online" and payment_status != "paid":
                print(f"[STATUS BLOCKED - UNPAID] Cannot process online order {order_id} because payment is {payment_status}")
                raise ValueError("Online orders must be paid before processing.")
            
            if payment_method == "cod" and not is_cod_confirmed:
                print(f"[STATUS BLOCKED - COD NOT CONFIRMED] Cannot process COD order {order_id}")
                raise ValueError("COD orders must be confirmed by the buyer before processing.")

        now = get_current_time_iso()
        
        update_data = {"status": new_status.value, "updated_at": now}

        # 🚨 LOGISTICS INJECTION: Trigger Easyship Shipment Creation 🚨
        if new_status == OrderStatus.READY_FOR_SHIPMENT:
            print(f"[ORDER] Status is READY_FOR_SHIPMENT. Triggering Easyship for {order_id}")
            
            # 1. Validation: Payment check
            payment_status = order_doc.get("payment_status", "unpaid")
            payment_method = order_doc.get("payment_method", "ONLINE") # Default to online if not specified
            
            if payment_method != "COD" and payment_status != "paid":
                raise ValueError("Online orders must be paid before creating a shipment.")
                
            # 2. Fetch Seller Info for Origin Address
            seller_id = order_doc.get("seller_id")
            seller_doc = db.collection("sellers").document(seller_id).get()
            if not seller_doc.exists:
                raise ValueError(f"Seller {seller_id} not found. Cannot create shipment.")
            
            seller_data = seller_doc.to_dict()
            
            # 3. Prepare Easyship Payload
            items = order_doc.get("items", [])
            shipping_address = order_doc.get("shipping_address", {})
            shipping_details = order_doc.get("shipping_details", {})
            
            easyship_payload = {
                "order_id": order_id,
                "payment_method": payment_method,
                "total_price": order_doc.get("total_price", 0),
                "origin_address": {
                    "line_1": seller_data.get("street", "Seller Street"),
                    "city": seller_data.get("city", "Manila"),
                    "state": seller_data.get("province", "Metro Manila"),
                    "postal_code": seller_data.get("postal_code", "1000"),
                    "country_alpha2": "PH",
                    "contact_name": seller_data.get("store_name", "Swipify Seller"),
                    "contact_phone": seller_data.get("phone_number", "+639123456789"),
                    "contact_email": "seller@swipify.com"
                },
                "destination_address": {
                    "line_1": shipping_address.get("street", ""),
                    "city": shipping_address.get("city", ""),
                    "state": shipping_address.get("region", ""),
                    "postal_code": shipping_address.get("postal_code", ""),
                    "country_alpha2": "PH",
                    "contact_name": shipping_address.get("full_name", "Customer"),
                    "contact_phone": shipping_address.get("phone", ""),
                    "contact_email": "customer@example.com"
                },
                "courier_id": shipping_details.get("id", "standard_courier_id"), # In a real app, this would be a real Easyship courier ID
                "total_weight": sum(item.get("quantity", 1) * 0.5 for item in items),
                "items": [
                    {
                        "description": item.get("name", "Product"),
                        "sku": item.get("product_id", "SKU"),
                        "quantity": item.get("quantity", 1),
                        "actual_weight": 0.5,
                        "declared_currency": "PHP",
                        "declared_customs_value": item.get("price", 0)
                    } for item in items
                ]
            }
            
            # 4. Call Easyship Service (Async call in a sync service, using a helper if needed or just await)
            # Since update_order_status_service is sync, and create_easyship_shipment is async,
            # we should ideally make this service async or use a loop.
            # But the existing codebase seems to mix them. I'll use asyncio if needed or make the service async.
            import asyncio
            try:
                # Note: This might block if not handled correctly in a sync context, but FastAPI runs sync def in threadpool.
                shipment_result = asyncio.run(create_easyship_shipment(easyship_payload))
                
                # 5. Update Order with tracking details
                update_data["tracking_number"] = shipment_result["tracking_number"]
                update_data["logistic_provider"] = shipment_result["courier"]
                update_data["label_url"] = shipment_result["label_url"]
                update_data["shipment_id"] = shipment_result["shipment_id"]
                update_data["status"] = OrderStatus.LABEL_CREATED.value # Move to LABEL_CREATED automatically
                
                # 6. Create Dedicated Shipment Document
                db.collection("shipments").document(shipment_result["shipment_id"]).set({
                    "order_id": order_id,
                    "tracking_number": shipment_result["tracking_number"],
                    "status": "label_created",
                    "courier": shipment_result["courier"],
                    "label_url": shipment_result["label_url"],
                    "last_location": "Awaiting Pickup",
                    "last_updated_timestamp": firestore.SERVER_TIMESTAMP,
                    "created_at": now,
                    "updated_at": now
                })
                
                print(f"[ORDER] Shipment created for {order_id}: {shipment_result['tracking_number']}")
                
            except Exception as e:
                print(f"[ORDER] ❌ Easyship Error for {order_id}: {str(e)}")
                # We might want to move to an EXCEPTION status if API fails
                update_data["status"] = OrderStatus.EXCEPTION.value
                update_data["notes"] = f"Easyship API Failure: {str(e)}"
                # Continue so the status update still happens but to EXCEPTION

        # 🚨 DELIVERY (COD PAYMENT) 🚨
        if new_status == OrderStatus.DELIVERED:
            payment_method = order_doc.get("payment_method", "online").lower()
            if payment_method == "cod":
                print(f"[COD PAYMENT COLLECTED] Order {order_id} DELIVERED. Marking as paid.")
                update_data["payment_status"] = "paid"

        # Update order status and append to status_history list

        update_data["status_history"] = firestore.ArrayUnion([
            {
                "timestamp": now,
                "old_status": current_status.value,
                "new_status": new_status.value,
                "updated_by": "system",
            }
        ])
        order_ref.update(update_data)
                
        # 🚨 STOCK REVERSION 🚨
        if new_status == OrderStatus.CANCELLED:
            print(f"[STOCK REVERSION] Order {order_id} CANCELLED. Reverting stock.")
            items = order_doc.get("items", [])
            batch_revert_order_stock_service(items)

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
            OrderStatus.COMPLETED.value: "Order Completed! ✨",
            OrderStatus.CANCELLED.value: "Order Cancelled ❌",
        }
        if new_status.value in buyer_titles:
            msg = f"Your order {order_id[:8]} is now {new_status.value}."
            if new_status == OrderStatus.SHIPPED:
                msg += f" Tracking: {update_data.get('tracking_number')}"
            create_notification(buyer_id, buyer_titles[new_status.value], msg, "ORDER_UPDATE")

        # 🚨 EMAIL: Send email notification for shipped/delivered 🚨
        send_order_status_email(
            user_id=buyer_id,
            order_id=order_id,
            new_status=new_status.value,
            tracking_number=update_data.get("tracking_number"),
            logistic_provider=update_data.get("logistic_provider"),
        )

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
        print(f"[UPDATE PAYMENT STATUS ERROR] {str(e)}")
        raise e

def confirm_cod_service(order_id: str) -> dict:
    """Mark a COD order as confirmed by the buyer."""
    try:
        order_ref = db.collection("orders").document(order_id)
        order_doc = order_ref.get()
        if not order_doc.exists:
            raise ValueError(f"Order {order_id} not found")

        payment_method = order_doc.get("payment_method", "online").lower()
        if payment_method != "cod":
            raise ValueError("Order is not a Cash on Delivery order.")
            
        if order_doc.get("is_cod_confirmed", False):
            raise ValueError("COD order is already confirmed.")

        now = get_current_time_iso()
        order_ref.update(
            {
                "is_cod_confirmed": True, 
                "updated_at": now
            }
        )
        
        # Log status transition conceptually (no state change, just payment auth)
        db.collection("orders").document(order_id).collection("status_history").add(
            {
                "timestamp": now,
                "old_status": order_doc.get("status"),
                "new_status": order_doc.get("status"),
                "updated_by": "buyer",
                "notes": "COD Order Confirmed"
            }
        )

        final_doc = order_ref.get().to_dict()
        final_doc["id"] = order_id
        return final_doc
    except Exception as e:
        print(f"[CONFIRM COD ERROR] {str(e)}")
        raise e

def get_order_status_history(order_id: str) -> list:
    """Fetch the status_history for an order, preferring the embedded field."""
    try:
        order_doc = db.collection("orders").document(order_id).get()
        if order_doc.exists:
            order_data = order_doc.to_dict()
            if "status_history" in order_data:
                return order_data["status_history"]
        
        # Fallback to subcollection
        docs = (
            db.collection("orders")
            .document(order_id)
            .collection("status_history")
            .order_by("timestamp")
            .get()
        )
        return [doc.to_dict() for doc in docs]
    except Exception as e:
        print(f"[STATUS HISTORY ERROR] {e}")
        return []


def get_order_by_id(order_id: str) -> dict:
    """Fetch an order by its ID, including its status_history."""
    doc = db.collection("orders").document(order_id).get()
    if not doc.exists:
        raise ValueError("Order not found")
    
    order = doc.to_dict()
    order["id"] = doc.id
    order["status_history"] = get_order_status_history(order_id)
    return order

import io
import csv

def generate_seller_orders_csv_service(seller_id: str):
    """"Generate a CSV report of all orders for a seller."""
    try:
        orders = get_seller_orders_service(seller_id)
        
        output = io.StringIO()
        writer = csv.writer(output)
        
        # Header
        writer.writerow([
            "Order ID", "Date", "Customer ID", "Items", "Total Price", 
            "Status", "Payment", "Shipping Provider", "Tracking Number"
        ])
        
        for order in orders:
            # Flatten items for CSV
            items_str = "; ".join([f"{item['name']} (x{item['quantity']})" for item in order.get("items", [])])
            
            writer.writerow([
                order.get("id"),
                order.get("created_at"),
                order.get("user_id"),
                items_str,
                f"PHP {order.get('total_price', 0.0):.2f}",
                order.get("status"),
                order.get("payment_status"),
                order.get("logistic_provider"),
                order.get("tracking_number") or "N/A"
            ])
            
        return output.getvalue()
    except Exception as e:
        print(f"[REPORT ERROR] {str(e)}")
        raise e
