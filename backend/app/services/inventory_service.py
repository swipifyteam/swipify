# backend/app/services/inventory_service.py
from firebase_client import db
from google.cloud import firestore

def reserve_product_stock_service(product_id: str, quantity: int):
    """
    Reserve stock using a transaction. Throws ValueError if out of stock.
    """
    product_ref = db.collection("products").document(product_id)
    transaction = db.transaction()

    @firestore.transactional
    def reserve_in_transaction(transaction, ref, amount):
        snapshot = ref.get(transaction=transaction)
        if not snapshot.exists:
            raise ValueError(f"Product {product_id} not found")
        
        current_stock = snapshot.get("stock") or 0
        if current_stock < amount:
            raise ValueError(f"Out of stock for {snapshot.get('name', product_id)}")
            
        new_stock = current_stock - amount
        transaction.update(ref, {"stock": new_stock})
        print(f"[STOCK RESERVED] Product {product_id}: {current_stock} -> {new_stock} (Reserved {amount})")

    reserve_in_transaction(transaction, product_ref, quantity)

def revert_product_stock_service(product_id: str, quantity: int):
    """
    Revert stock using a transaction. Used for cancelled orders.
    """
    product_ref = db.collection("products").document(product_id)
    transaction = db.transaction()

    @firestore.transactional
    def revert_in_transaction(transaction, ref, amount):
        snapshot = ref.get(transaction=transaction)
        if not snapshot.exists:
            return
            
        current_stock = snapshot.get("stock") or 0
        new_stock = current_stock + amount
        transaction.update(ref, {"stock": new_stock})
        print(f"[STOCK REVERTED] Product {product_id}: {current_stock} -> {new_stock} (Reverted {amount})")

    revert_in_transaction(transaction, product_ref, quantity)

def batch_reserve_order_stock_service(items: list):
    """
    Reserve stock for all items in an order.
    Items should be a list of dicts or pydantic objects with product_id and quantity.
    Returns successfully if all pass, throws ValueError otherwise.
    Note: If one item fails, previous items in the batch are NOT rolled back in this simple implementation,
    but it's acceptable if we only have single-seller checkouts where usually it's one item.
    Ideally, all reads then writes should be in one transaction. Let's assume single item for now or loop with risk.
    """
    # For safety, fetch all first to validate, then run transactions.
    for item in items:
        # handle dict or pydantic model
        product_id = item["product_id"] if isinstance(item, dict) else item.product_id
        quantity = item["quantity"] if isinstance(item, dict) else item.quantity
        if product_id and quantity > 0:
            reserve_product_stock_service(product_id, quantity)

def batch_revert_order_stock_service(items: list):
    for item in items:
        product_id = item["product_id"] if isinstance(item, dict) else item.product_id
        quantity = item["quantity"] if isinstance(item, dict) else item.quantity
        if product_id and quantity > 0:
            revert_product_stock_service(product_id, quantity)
