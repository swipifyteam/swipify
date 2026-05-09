from fastapi import APIRouter, HTTPException, Path, Body, BackgroundTasks, Depends, Query
from typing import List, Optional
from app.models.order import (
    OrderCreateRequest,
    OrderStatusUpdateRequest,
    OrderPaymentUpdateRequest,
    OrderResponse,
    BuyNowRequest,
    CalculateTotalResponse,
    CalculateTotalRequest,
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
    get_order_by_id,
    confirm_cod_service
)
from app.utils.auth_utils import get_current_user, verify_owner
from firebase_client import db

router = APIRouter()


@router.post("/", response_model=OrderResponse, status_code=201)
async def create_order(order_data: OrderCreateRequest, token: dict = Depends(get_current_user)):
    """Create a new order from cart checkout."""
    # [SECURITY] Prevent user from creating orders for other users
    verify_owner(order_data.user_id, token["uid"])
    try:
        order = await create_order_service(order_data)
        return OrderResponse(**order)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/buy-now", response_model=OrderResponse, status_code=201)
async def create_buy_now_order(buy_data: BuyNowRequest, token: dict = Depends(get_current_user)):
    """Create a new order directly without using the cart."""
    verify_owner(buy_data.user_id, token["uid"])
    try:
        order = await buy_now_service(buy_data)
        return OrderResponse(**order)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/user/{user_id}", response_model=List[OrderResponse])
async def get_user_orders(
    user_id: str = Path(...), 
    limit: int = Query(10, ge=1, le=50),
    last_doc_id: Optional[str] = Query(None),
    token: dict = Depends(get_current_user)
):
    """Return all orders of a user."""
    verify_owner(user_id, token["uid"])
    try:
        orders = await get_user_orders_service(user_id, limit, last_doc_id)
        return orders
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/seller/{seller_id}", response_model=List[OrderResponse])
async def get_seller_orders(
    seller_id: str = Path(...),
    limit: int = Query(10, ge=1, le=50),
    last_doc_id: Optional[str] = Query(None),
    token: dict = Depends(get_current_user)
):
    """Return all seller orders."""
    # [SECURITY] Verify seller ownership
    seller_doc = db.collection("sellers").document(seller_id).get()
    if not seller_doc.exists or seller_doc.to_dict().get("user_id") != token["uid"]:
        raise HTTPException(status_code=403, detail="Unauthorized: You do not own this shop")
    
    try:
        orders = await get_seller_orders_service(seller_id, limit, last_doc_id)
        return orders
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats/{seller_id}")
async def get_seller_stats(seller_id: str = Path(...), token: dict = Depends(get_current_user)):
    """Return seller statistics."""
    seller_doc = db.collection("sellers").document(seller_id).get()
    if not seller_doc.exists or seller_doc.to_dict().get("user_id") != token["uid"]:
        raise HTTPException(status_code=403, detail="Unauthorized")
    
    try:
        stats = await calculate_seller_earnings_service(seller_id)
        return stats
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{order_id}/status", response_model=OrderResponse)
async def update_order_status(
    background_tasks: BackgroundTasks,
    order_id: str = Path(...),
    update_data: OrderStatusUpdateRequest = Body(...),
    token: dict = Depends(get_current_user)
):
    """Update order status. Typically called by the seller."""
    # [SECURITY] Verify order belongs to a shop owned by the user
    order = await get_order_by_id(order_id)
    seller_id = order.get("seller_id")
    seller_doc = db.collection("sellers").document(seller_id).get()
    if not seller_doc.exists or seller_doc.to_dict().get("user_id") != token["uid"]:
        raise HTTPException(status_code=403, detail="Unauthorized: Not the seller of this order")
    
    try:
        updated_order = await update_order_status_service(order_id, update_data.status, background_tasks)
        return updated_order
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/detail/{order_id}", response_model=OrderResponse)
async def get_order_detail(order_id: str = Path(...), token: dict = Depends(get_current_user)):
    """Get full order details."""
    try:
        order = await get_order_by_id(order_id)
        # [SECURITY] Verify user or seller ownership
        if order.get("user_id") != token["uid"]:
             seller_doc = db.collection("sellers").document(order.get("seller_id")).get()
             if not seller_doc.exists or seller_doc.to_dict().get("user_id") != token["uid"]:
                 raise HTTPException(status_code=403, detail="Unauthorized")
        
        return OrderResponse(**order)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{order_id}/tracking", response_model=TrackingResponse)
async def get_order_tracking(order_id: str = Path(...), token: dict = Depends(get_current_user)):
    """Get tracking history."""
    try:
        order = await get_order_by_id(order_id)
        if order.get("user_id") != token["uid"]:
             seller_doc = db.collection("sellers").document(order.get("seller_id")).get()
             if not seller_doc.exists or seller_doc.to_dict().get("user_id") != token["uid"]:
                 raise HTTPException(status_code=403, detail="Unauthorized")

        return TrackingResponse(
            tracking_number=order.get("tracking_number"),
            status=order.get("status"),
            status_history=order.get("status_history", []),
            courier=order.get("logistic_provider")
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{order_id}/confirm-cod", response_model=OrderResponse)
async def confirm_cod_order(order_id: str = Path(...), token: dict = Depends(get_current_user)):
    """Confirm a COD order."""
    order = await get_order_by_id(order_id)
    verify_owner(order.get("user_id"), token["uid"])
    
    try:
        updated_order = await confirm_cod_service(order_id)
        return updated_order
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
