# backend/app/services/inventory_service.py
from firebase_client import db
from google.cloud import firestore

def deduct_product_stock_service(product_id: str, quantity: int):
    """
    Safely deduct quantity from product stock using a transaction.
    """
    product_ref = db.collection("products").document(product_id)

    @firestore.transactional
    def deduct_in_transaction(transaction, ref, amount):
        snapshot = ref.get(transaction=transaction)
        if not snapshot.exists:
            print(f"[INVENTORY ERROR] Product {product_id} not found")
            return
        
        current_stock = snapshot.get("stock") or 0
        new_stock = max(0, current_stock - amount)
        
        transaction.update(ref, {"stock": new_stock})
        print(f"[INVENTORY UPDATE] Product {product_id}: {current_stock} -> {new_stock} (Deducted {amount})")

    transaction = db.transaction()
    deduct_in_transaction(transaction, product_ref, quantity)

def batch_deduct_order_stock_service(items: list):
    """
    Deduct stock for all items in an order.
    Items should be a list of dicts with product_id and quantity.
    """
    for item in items:
        product_id = item.get("product_id")
        quantity = item.get("quantity", 0)
        if product_id and quantity > 0:
            deduct_product_stock_service(product_id, quantity)
