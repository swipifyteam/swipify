# app/seller/orders_seller.py
# Seller-specific Order Management and Analytics for Swipify.

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.order_service import (
    get_seller_orders_service, 
    calculate_seller_earnings_service,
    update_order_status_service
)

router = APIRouter()

class OrderStatusUpdateRequest(BaseModel):
    status: str

@router.get("/{seller_id}")
async def get_seller_orders(seller_id: str):
    """
    Fetch all customer orders belonging to this seller.
    Delegates to order_service for consistent Firestore querying.
    """
    try:
        print(f"[SELLER API] Fetching customer orders for seller: {seller_id}")
        orders = get_seller_orders_service(seller_id)
        return {"orders": orders}
    except Exception as e:
        print(f"[SELLER API ERROR] {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/stats/{seller_id}")
async def get_seller_stats(seller_id: str):
    """
    🚨 PART 6/7 FIX: REAL DATA (EARNINGS & COUNTS) 🚨
    Returns REAL calculated earnings and order counts instead of static/fake data.
    """
    try:
        print(f"[SELLER API] Calculating real-time stats for seller: {seller_id}")
        stats = calculate_seller_earnings_service(seller_id)
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/{order_id}/status")
async def update_order_status(order_id: str, request: OrderStatusUpdateRequest):
    """
    Update the status of an order (e.g., from 'Packaged' to 'Shipped').
    Triggers EARNINGS update when marked 'Delivered'.
    """
    try:
        # Use common status update service
        # Normalizes status case and handles logging
        print(f"[SELLER API] Updating order {order_id} status to {request.status}")
        updated_order = update_order_status_service(order_id, request.status)
        
        return {
            "message": "Order status updated successfully", 
            "new_status": updated_order.get("status"),
            "order": updated_order
        }
    except ValueError as v_err:
        raise HTTPException(status_code=400, detail=str(v_err))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
