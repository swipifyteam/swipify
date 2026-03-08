# app/routes/cart.py
# Cart API endpoints for the Swipify ecommerce platform.
# Handles fetching, adding, removing, and updating cart items.
# Cart is stored in Firestore under: carts/{userId}/items/{productId}

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from firebase_client import db
from google.cloud.firestore_v1 import SERVER_TIMESTAMP

router = APIRouter()


# ── Request Schemas ──────────────────────────────────────────────────────────

class AddToCartRequest(BaseModel):
    """Request body for adding a product to the cart."""
    userId: str
    productId: str


class RemoveFromCartRequest(BaseModel):
    """Request body for removing a product from the cart."""
    userId: str
    productId: str


class UpdateCartRequest(BaseModel):
    """Request body for updating a cart item's quantity."""
    userId: str
    productId: str
    quantity: int


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/{user_id}")
async def get_cart(user_id: str):
    """Fetch all cart items for the given user.
    
    Returns cart items enriched with full product data (name, price, images).
    """
    try:
        # Get all items in the user's cart sub-collection
        items_ref = db.collection("carts").document(user_id).collection("items").get()
        cart_items = []

        for item_doc in items_ref:
            item = item_doc.to_dict()
            item["productId"] = item_doc.id

            # Fetch the full product data for each cart item
            product_doc = db.collection("products").document(item_doc.id).get()
            if product_doc.exists:
                item["product"] = product_doc.to_dict()
                item["product"]["id"] = product_doc.id

            cart_items.append(item)

        return {"userId": user_id, "items": cart_items}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/add")
async def add_to_cart(request: AddToCartRequest):
    """Add a product to the user's cart.
    
    If the product already exists in the cart, increment its quantity by 1.
    If it doesn't exist, create a new cart item with quantity = 1.
    """
    try:
        item_ref = (
            db.collection("carts")
            .document(request.userId)
            .collection("items")
            .document(request.productId)
        )
        item_doc = item_ref.get()

        if item_doc.exists:
            # Product already in cart — increment quantity
            current_qty = item_doc.to_dict().get("quantity", 0)
            item_ref.update({"quantity": current_qty + 1})
            return {"message": "Quantity updated", "quantity": current_qty + 1}
        else:
            # New cart item — add with quantity = 1
            item_ref.set({
                "quantity": 1,
                "addedAt": SERVER_TIMESTAMP,
            })
            return {"message": "Item added to cart", "quantity": 1}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/remove")
async def remove_from_cart(request: RemoveFromCartRequest):
    """Completely remove a product from the user's cart."""
    try:
        item_ref = (
            db.collection("carts")
            .document(request.userId)
            .collection("items")
            .document(request.productId)
        )
        item_ref.delete()
        return {"message": "Item removed from cart"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/update")
async def update_cart_quantity(request: UpdateCartRequest):
    """Update the quantity of a specific cart item.
    
    If quantity is <= 0, the item is removed from the cart.
    """
    try:
        item_ref = (
            db.collection("carts")
            .document(request.userId)
            .collection("items")
            .document(request.productId)
        )

        if request.quantity <= 0:
            # Remove item if quantity is 0 or less
            item_ref.delete()
            return {"message": "Item removed (quantity was 0)"}

        item_ref.update({"quantity": request.quantity})
        return {"message": "Quantity updated", "quantity": request.quantity}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
