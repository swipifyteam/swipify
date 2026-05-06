from fastapi import APIRouter, HTTPException, Path, Body, BackgroundTasks
from typing import List
from app.models.order import (
    OrderCreateRequest,
    OrderStatusUpdateRequest,
    OrderPaymentUpdateRequest,
    OrderResponse,
    BuyNowRequest,
    CalculateTotalRequest,
    CalculateTotalResponse,
    StatusHistoryEntry,
    TrackingResponse
)
from app.services.order_service import (
    create_order_service,
    buy_now_service,
    get_user_orders_service,
    get_seller_orders_service,
    calculate_seller_earnings_service,
    update_order_status_service,
    update_order_payment_service,
    get_order_by_id,
    get_order_status_history,
    confirm_cod_service
)
from firebase_client import db

router = APIRouter()


@router.post("/", response_model=OrderResponse, status_code=201)
async def create_order(order_data: OrderCreateRequest):
    """Create a new order from cart checkout."""
    print(f"[ORDERS API] POST /orders/ — user={order_data.user_id}, seller={order_data.seller_id}, items={len(order_data.items)}")
    try:
        order = create_order_service(order_data)
        print(f"[ORDERS API] ✅ Order created: id={order['id']}")
        return OrderResponse(**order)
    except ValueError as e:
        print(f"[ORDERS API] ❌ Validation error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        # Log the REAL error so we can debug it
        print(f"[ORDERS API] ❌ Unexpected error creating order: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/calculate-total", response_model=CalculateTotalResponse)
def calculate_order_total(request: CalculateTotalRequest):
    """Computes shipping fee completely backend-side with strict 120/170 enforcement or dynamic fallback"""
    try:
        if request.shipping_fee is not None:
            shipping_fee = request.shipping_fee
        else:
            provider_ref = db.collection("shipping_providers").document(request.provider_id)
            provider_doc = provider_ref.get()
            
            if provider_doc.exists:
                p_data = provider_doc.to_dict()
                base_fee = p_data.get("base_fee", 40.0)
                distance_fee = p_data.get("per_km", 8.0) * request.distance_km
                weight_fee = p_data.get("per_kg", 5.0) * request.weight_kg
                shipping_fee = base_fee + distance_fee + weight_fee
            else:
                # Fallback purely as safety if DB is uninitialized, but not strictly hardcoded business logic
                base_fee = 40.0
                distance_fee = 8.0 * request.distance_km
                weight_fee = 5.0 * request.weight_kg
                shipping_fee = base_fee + distance_fee + weight_fee
            
            # Use dynamic min/max limits if available in DB
            min_fee = p_data.get("min_fee", 120.0) if provider_doc.exists else 120.0
            max_fee = p_data.get("max_fee", 250.0) if provider_doc.exists else 250.0

            if shipping_fee < min_fee:
                shipping_fee = min_fee
            if shipping_fee > max_fee:
                shipping_fee = max_fee
            
        shipping_fee = round(shipping_fee, 2)
        total = round(request.subtotal + shipping_fee, 2)
        
        return CalculateTotalResponse(
            subtotal=request.subtotal,
            shipping_fee=shipping_fee,
            total=total
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/buy-now", response_model=OrderResponse, status_code=201)
async def create_buy_now_order(buy_data: BuyNowRequest):
    """Create a new order directly without using the cart."""
    print(f"[ORDERS API] POST /orders/buy-now — user={buy_data.user_id}, product={buy_data.product_id}")
    try:
        order = buy_now_service(buy_data)
        print(f"[ORDERS API] ✅ Buy Now order created: id={order['id']}")
        return OrderResponse(**order)
    except ValueError as e:
        print(f"[ORDERS API] ❌ Validation error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[ORDERS API] ❌ Unexpected error in Buy Now: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/debug/all")
async def debug_list_all_orders():
    """DEV ONLY — list all orders in Firestore to verify writes are working."""
    try:
        docs = db.collection("orders").limit(20).get()
        orders = []
        for doc in docs:
            d = doc.to_dict()
            orders.append({
                "id": d.get("id", doc.id),
                "user_id": d.get("user_id"),
                "seller_id": d.get("seller_id"),
                "status": d.get("status"),
                "total_price": d.get("total_price"),
                "created_at": d.get("created_at"),
                "items_count": len(d.get("items", [])),
            })
        print(f"[DEBUG] Total orders in Firestore: {len(orders)}")
        return {"total": len(orders), "orders": orders}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/user/{user_id}", response_model=List[OrderResponse])
async def get_user_orders(user_id: str = Path(..., description="The ID of the user")):
    """Return all orders of a user."""
    print(f"[ORDERS API] GET /orders/user/{user_id}")
    try:
        orders = get_user_orders_service(user_id)
        print(f"[ORDERS API] Found {len(orders)} orders for user={user_id}")
        return orders
    except Exception as e:
        print(f"[ORDERS API] ❌ Error fetching user orders: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/seller/{seller_id}", response_model=List[OrderResponse])
async def get_seller_orders(seller_id: str = Path(..., description="The ID of the seller")):
    """Return all seller orders."""
    print(f"[ORDERS API] GET /orders/seller/{seller_id}")
    try:
        orders = get_seller_orders_service(seller_id)
        print(f"[ORDERS API] Found {len(orders)} orders for seller={seller_id}")
        return orders
    except Exception as e:
        print(f"[ORDERS API] ❌ Error fetching seller orders: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats/{seller_id}")
async def get_seller_stats(seller_id: str = Path(..., description="The ID of the seller")):
    """Return seller statistics (earnings, order count)."""
    print(f"[ORDERS API] GET /orders/stats/{seller_id}")
    try:
        stats = calculate_seller_earnings_service(seller_id)
        return stats
    except Exception as e:
        print(f"[ORDERS API] ❌ Error fetching seller stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{order_id}/status", response_model=OrderResponse)
async def update_order_status(
    background_tasks: BackgroundTasks,
    order_id: str = Path(..., description="The ID of the order"),
    update_data: OrderStatusUpdateRequest = Body(...)
):
    """Update order status. Typically called by the seller."""
    print(f"[ORDERS API] PUT /orders/{order_id}/status — new status={update_data.status}")
    try:
        updated_order = update_order_status_service(order_id, update_data.status, background_tasks)
        return updated_order
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[ORDERS API] ❌ Error updating order status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{order_id}/payment", response_model=OrderResponse)
async def update_order_payment(
    order_id: str = Path(..., description="The ID of the order"),
    update_data: OrderPaymentUpdateRequest = Body(...)
):
    """Update order payment status."""
    print(f"[ORDERS API] PUT /orders/{order_id}/payment — new payment_status={update_data.payment_status}")
    try:
        updated_order = update_order_payment_service(order_id, update_data.payment_status)
        return updated_order
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[ORDERS API] ❌ Error updating payment status: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{order_id}/confirm-cod", response_model=OrderResponse)
async def confirm_cod_order(
    order_id: str = Path(..., description="The ID of the order")
):
    """Confirm a COD order to allow processing by the seller."""
    print(f"[ORDERS API] POST /orders/{order_id}/confirm-cod")
    try:
        updated_order = confirm_cod_service(order_id)
        return updated_order
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[ORDERS API] ❌ Error confirming COD order: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/detail/{order_id}", response_model=OrderResponse)
async def get_order_detail(
    order_id: str = Path(..., description="The ID of the order")
):
    """Get full order details including status history and tracking."""
    print(f"[ORDERS API] GET /orders/{order_id}")
    try:
        order = get_order_by_id(order_id)
        return OrderResponse(**order)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        print(f"[ORDERS API] ❌ Error fetching order detail: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{order_id}/tracking", response_model=TrackingResponse)
async def get_order_tracking(
    order_id: str = Path(..., description="The ID of the order")
):
    """Get tracking / status history for an order."""
    print(f"[ORDERS API] [TRACKING FETCH] {order_id}")
    try:
        order = get_order_by_id(order_id)
        print(f"[ORDERS API] [TRACKING DATA] {order.get('tracking_number')}")
        
        return TrackingResponse(
            tracking_number=order.get("tracking_number"),
            status=order.get("status"),
            status_history=order.get("status_history", []),
            courier=order.get("logistic_provider")
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        print(f"[ORDERS API] ❌ Error fetching tracking: {e}")
        raise HTTPException(status_code=500, detail=str(e))
