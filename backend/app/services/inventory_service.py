# backend/app/services/inventory_service.py
from firebase_client import db
from google.cloud import firestore

def batch_reserve_order_stock_service(items: list):
    """
    Reserve stock for all items in an order using a SINGLE ATOMIC TRANSACTION.
    This prevents the 'Partial Failure' where some items are reserved and others fail.
    """
    transaction = db.transaction()
    
    @firestore.transactional
    def reserve_in_batch(transaction, items_list):
        updates = []
        for item in items_list:
            p_id = item["product_id"] if isinstance(item, dict) else item.product_id
            qty = item["quantity"] if isinstance(item, dict) else item.quantity
            
            if not p_id or qty <= 0:
                continue
                
            ref = db.collection("products").document(p_id)
            snap = ref.get(transaction=transaction)
            
            if not snap.exists:
                raise ValueError(f"Product {p_id} not found")
                
            current_stock = snap.get("stock") or 0
            if current_stock < qty:
                raise ValueError(f"Out of stock: {snap.to_dict().get('name', 'Product')} (Available: {current_stock}, Requested: {qty})")
            
            updates.append((ref, current_stock - qty))
        
        # After all reads are successful, perform all writes
        for ref, new_stock in updates:
            transaction.update(ref, {"stock": new_stock})

    reserve_in_batch(transaction, items)


def batch_revert_order_stock_service(items: list):
    """
    Revert stock for all items in an order using a SINGLE ATOMIC TRANSACTION.
    Used when an order is cancelled or payment fails.
    """
    transaction = db.transaction()
    
    @firestore.transactional
    def revert_in_batch(transaction, items_list):
        for item in items_list:
            p_id = item["product_id"] if isinstance(item, dict) else item.product_id
            qty = item["quantity"] if isinstance(item, dict) else item.quantity
            
            if not p_id or qty <= 0:
                continue
                
            ref = db.collection("products").document(p_id)
            snap = ref.get(transaction=transaction)
            
            if snap.exists:
                current_stock = snap.get("stock") or 0
                transaction.update(ref, {"stock": current_stock + qty})

    revert_in_batch(transaction, items)
