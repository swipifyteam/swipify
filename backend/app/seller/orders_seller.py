from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_client import db

router = APIRouter()

class OrderStatusUpdateRequest(BaseModel):
    status: str

@router.get("/{seller_id}")
async def get_seller_orders(seller_id: str):
    """Fetch orders belonging to the shop owned by this seller."""
    try:
        # Resolve shop_id for this seller
        user_doc = db.collection("users").document(seller_id).get()
        shop_id = None
        if user_doc.exists:
            shop_id = user_doc.to_dict().get("shop_id")
        
        # Query orders by shop_id (preferred) or direct seller_id
        if shop_id:
            docs = db.collection("orders").where("shopId", "==", shop_id).get()
        else:
            # Fallback for manual seller mappings
            docs = db.collection("orders").where("sellerId", "==", seller_id).get()
            
        orders = []
        for doc in docs:
            order = doc.to_dict()
            order.pop("createdAt", None) # Remove sentinel for serialisation
            order["id"] = doc.id
            orders.append(order)
            
        print(f"[ORDER] Streamed {len(orders)} orders for shop {shop_id or seller_id}")
        return {"orders": orders}
    except Exception as e:
        print(f"[ORDER] ERROR: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/{order_id}/status")
async def update_order_status(order_id: str, request: OrderStatusUpdateRequest):
    """Update the status of an order."""
    try:
        doc_ref = db.collection("orders").document(order_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Order not found")
        
        valid_statuses = ["Pending", "Packaged", "Shipped", "Delivered", "Cancelled"]
        if request.status not in valid_statuses:
            raise HTTPException(status_code=400, detail="Invalid status")
            
        doc_ref.update({"status": request.status})
        
        return {"message": "Order status updated successfully", "new_status": request.status}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
