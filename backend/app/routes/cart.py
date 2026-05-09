# app/routes/cart.py
# Cart API endpoints for the Swipify ecommerce platform.
# Handles fetching, adding, removing, and updating cart items.
# Cart is stored in Firestore under: carts/{userId}/items/{productId}

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from app.utils.auth_utils import get_current_user, verify_owner

router = APIRouter()


# ── Request Schemas ──────────────────────────────────────────────────────────

class AddToCartRequest(BaseModel):
    """Request body for adding a product to the cart."""
    userId: str
    productId: str
    quantity: int = 1


class RemoveFromCartRequest(BaseModel):
    """Request body for removing a product from the cart."""
    userId: str
    productId: str


class UpdateCartRequest(BaseModel):
    """Request body for updating a cart item's quantity."""
    userId: str
    productId: str
    quantity: int


class ClearCartRequest(BaseModel):
    """Request body for clearing the whole cart."""
    userId: str


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/{user_id}")
async def get_cart(user_id: str, token: dict = Depends(get_current_user)):
    """Fetch all cart items for the given user."""
    verify_owner(user_id, token["uid"])
    try:
        items_ref = db.collection("carts").document(user_id).collection("items").get()
        cart_items = []
        total_price = 0.0

        for item_doc in items_ref:
            item = item_doc.to_dict()
            product_id = item_doc.id
            item["productId"] = product_id

            product_doc = db.collection("products").document(product_id).get()
            if product_doc.exists:
                p_data = product_doc.to_dict()
                p_data["id"] = product_id
                p_data["sellerId"] = p_data.get("sellerId") or p_data.get("seller_id") or ""
                p_data["seller_id"] = p_data["sellerId"]
                
                p_data.pop("createdAt", None)
                p_data.pop("updatedAt", None)

                item["product"] = p_data
                price = float(p_data.get("price", 0.0))
                qty = int(item.get("quantity", 1))
                total_price += (price * qty)
                cart_items.append(item)

        return {
            "userId": user_id, 
            "items": cart_items,
            "grandTotal": round(total_price, 2),
            "count": len(cart_items)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/add")
async def add_to_cart(request: AddToCartRequest, token: dict = Depends(get_current_user)):
    """Add or increment a product in the user's cart."""
    verify_owner(request.userId, token["uid"])
    try:
        # Verify product exists
        prod_check = db.collection("products").document(request.productId).get()
        if not prod_check.exists:
             raise HTTPException(status_code=404, detail="Product not found")

        item_ref = db.collection("carts").document(request.userId).collection("items").document(request.productId)
        item_doc = item_ref.get()

        if item_doc.exists:
            current_qty = item_doc.to_dict().get("quantity", 0)
            new_qty = current_qty + request.quantity
            item_ref.update({"quantity": new_qty})
            return {"message": "Quantity updated", "quantity": new_qty}
        else:
            item_ref.set({
                "quantity": request.quantity,
                "addedAt": SERVER_TIMESTAMP,
            })
            return {"message": "Item added to cart", "quantity": request.quantity}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/remove")
async def remove_from_cart(request: RemoveFromCartRequest, token: dict = Depends(get_current_user)):
    """Remove a product from the user's cart."""
    verify_owner(request.userId, token["uid"])
    try:
        db.collection("carts").document(request.userId).collection("items").document(request.productId).delete()
        return {"message": "Item removed from cart"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/update")
async def update_cart_quantity(request: UpdateCartRequest, token: dict = Depends(get_current_user)):
    """Explicitly set the quantity of a cart item."""
    verify_owner(request.userId, token["uid"])
    try:
        item_ref = db.collection("carts").document(request.userId).collection("items").document(request.productId)
        if request.quantity <= 0:
            item_ref.delete()
            return {"message": "Item removed (quantity 0)"}
        
        item_ref.update({"quantity": request.quantity})
        return {"message": "Quantity updated", "quantity": request.quantity}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/clear")
async def clear_cart(request: ClearCartRequest, token: dict = Depends(get_current_user)):
    """Clear all items in the user's cart."""
    verify_owner(request.userId, token["uid"])
    try:
        items_ref = db.collection("carts").document(request.userId).collection("items")
        docs = items_ref.get()
        for doc in docs:
            doc.reference.delete()
        return {"message": "Cart cleared"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
