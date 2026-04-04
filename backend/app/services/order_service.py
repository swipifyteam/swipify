# app/services/order_service.py
# Order Management logic for the Swipify ecommerce platform.
# Generates unique orders, groups by seller, and handles cart clearing.

import uuid
from datetime import datetime, timezone
from firebase_client import db
from app.models.order import OrderCreateRequest, OrderResponse, OrderItem

def get_current_time_iso() -> str:
    """Utility to get the current timestamp in ISO 8601 format."""
    return datetime.now(timezone.utc).isoformat()

def create_order_service(order_data: OrderCreateRequest) -> dict:
    """Business logic to create an order and clear the user's cart.
    
    Ensures each order has its own unique ID to prevent overwriting.
    """
    print(f"[ORDER] Creating order for user {order_data.user_id}, seller {order_data.seller_id}")
    
    try:
        # 1. Generate a NEW, UNIQUE UUID for this specific order
        # THIS PREVENTS OVERWRITING — always use uuid4
        order_id = str(uuid.uuid4())
        
        now = get_current_time_iso()
        
        # 2. Build the order dictionary
        # Explicit naming: seller_id and status mapping
        order_dict = {
            "id": order_id,
            "user_id": order_data.user_id,
            "seller_id": order_data.seller_id,
            "items": [item.dict() for item in order_data.items],
            "total_price": float(order_data.total_price),
            "status": "pending",           # Initial status (starts pending)
            "payment_status": "unpaid",     # Payment pending
            "created_at": now,
            "updated_at": now
        }
        
        # 3. Write specifically to the 'orders' collection (unique ID)
        db.collection("orders").document(order_id).set(order_dict)
        print(f"[ORDER CREATED] Success: ID={order_id}")
        
        # 🚨 PART 5 FIX: CLEAR THE CART AFTER CHECKOUT 🚨
        # We delete all items from this user's cart sub-collection
        # This keeps the UI clean and prevents double ordering the same items
        try:
            cart_ref = db.collection("carts").document(order_data.user_id).collection("items")
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
            if status == "delivered":
                total_earnings += float(order.get("total_price", 0.0))
                delivered_count += 1
        
        print(f"[EARNINGS CALCULATED] Seller={seller_id}, Total={total_earnings}, Delivered Order Count={delivered_count}")
        return {
            "total_earnings": total_earnings,
            "total_orders": total_orders_count,
            "delivered_count": delivered_count
        }
    except Exception as e:
        print(f"[EARNINGS ERROR] {str(e)}")
        return {"total_earnings": 0.0, "total_orders": 0, "delivered_count": 0}

def update_order_status_service(order_id: str, new_status: str) -> dict:
    """Safely update order status with logging."""
    try:
        order_ref = db.collection("orders").document(order_id)
        order_doc = order_ref.get()
        if not order_doc.exists:
            raise ValueError(f"Order {order_id} not found")
        
        order_ref.update({
            "status": new_status,
            "updated_at": get_current_time_iso()
        })
        
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
            
        order_ref.update({
            "payment_status": new_payment_status,
            "updated_at": get_current_time_iso()
        })
        
        final_doc = order_ref.get().to_dict()
        final_doc["id"] = order_id
        return final_doc
    except Exception as e:
        print(f"[UPDATE PAYMENT ERROR] {str(e)}")
        raise e
