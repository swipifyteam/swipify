from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_client import db

router = APIRouter()

class StockUpdateRequest(BaseModel):
    stock: int

@router.get("/{seller_id}")
async def get_inventory(seller_id: str):
    """Fetch inventory details for a seller."""
    try:
        docs = db.collection("products").where("sellerId", "==", seller_id).get()
        inventory = []
        for doc in docs:
            product = doc.to_dict()
            inventory.append({
                "id": doc.id,
                "name": product.get("name"),
                "stock": product.get("stock", 0),
                "price": product.get("price", 0.0)
            })
        return {"inventory": inventory}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.patch("/{product_id}/stock")
async def update_stock(product_id: str, request: StockUpdateRequest):
    """Update stock for a specific product."""
    try:
        doc_ref = db.collection("products").document(product_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Product not found")
            
        doc_ref.update({"stock": request.stock})
        return {"message": "Stock updated successfully", "new_stock": request.stock}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
