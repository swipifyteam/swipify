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
async def get_cart(user_id: str):
    """Fetch all cart items for the given user.
    
    Returns cart items ENRICHED with full product data (name, price, images, seller_id).
    Used by the Cart Screen to show real names and details instead of just IDs.
    """
    try:
        print(f"[CART] Fetching enriched cart for user: {user_id}")
        # Get all items in the user's cart sub-collection
        items_ref = db.collection("carts").document(user_id).collection("items").get()
        cart_items = []

        total_price = 0.0

        for item_doc in items_ref:
            item = item_doc.to_dict()
            product_id = item_doc.id
            item["productId"] = product_id

            # FETCH FULL PRODUCT DATA (Enrichment)
            product_doc = db.collection("products").document(product_id).get()
            if product_doc.exists:
                p_data = product_doc.to_dict()
                p_data["id"] = product_id

                # Support both naming conventions for compatibility
                p_data["sellerId"] = p_data.get("sellerId") or p_data.get("seller_id") or ""
                p_data["seller_id"] = p_data["sellerId"]
                
                # Cleanup sentinel fields
                p_data.pop("createdAt", None)
                p_data.pop("updatedAt", None)

                item["product"] = p_data
                
                # Calculate running total
                price = float(p_data.get("price", 0.0))
                qty = int(item.get("quantity", 1))
                total_price += (price * qty)
                
                cart_items.append(item)
            else:
                print(f"[CART] Warning: Product {product_id} is in cart but missing from products collection.")
                # We could auto-delete here, but safer to just skip for now.

        print(f"[CART] Successfully enriched {len(cart_items)} items for {user_id}")
        return {
            "userId": user_id, 
            "items": cart_items,
            "grandTotal": total_price,
            "count": len(cart_items)
        }
    except Exception as e:
        print(f"[CART ERROR] {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/add")
async def add_to_cart(request: AddToCartRequest):
    """Add or increment a product in the user's cart."""
    try:
        print(f"[CART] Adding {request.productId} to cart for {request.userId} (qty: {request.quantity})")
        
        # Verify product exists before adding
        prod_check = db.collection("products").document(request.productId).get()
        if not prod_check.exists:
             raise HTTPException(status_code=404, detail="Cannot add non-existent product to cart")

        item_ref = (
            db.collection("carts")
            .document(request.userId)
            .collection("items")
            .document(request.productId)
        )
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
        print(f"[CART ADD ERROR] {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/remove")
async def remove_from_cart(request: RemoveFromCartRequest):
    """Remove a product from the user's cart."""
    try:
        db.collection("carts").document(request.userId).collection("items").document(request.productId).delete()
        print(f"[CART] Removed {request.productId} for user {request.userId}")
        return {"message": "Item removed from cart"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/update")
async def update_cart_quantity(request: UpdateCartRequest):
    """Explicitly set the quantity of a cart item."""
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
async def clear_cart(request: ClearCartRequest):
    """Clear all items in the user's cart."""
    try:
        print(f"[CART] Clearing cart for user: {request.userId}")
        items_ref = db.collection("carts").document(request.userId).collection("items")
        # Delete all documents in subcollection
        docs = items_ref.get()
        for doc in docs:
            doc.reference.delete()
        return {"message": "Cart cleared"}
    except Exception as e:
        print(f"[CART CLEAR ERROR] {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
