import sys
sys.path.append('./app')
from firebase_client import db

try:
    orders_ref = db.collection('orders').select(["status", "total_price", "refund_requested"]).stream()
    gmv = 0.0
    total_orders = 0
    for doc in orders_ref:
        data = doc.to_dict()
        total_orders += 1
        if data.get("status") in ["completed", "delivered"]:
            gmv += float(data.get("total_price", 0))
    print("TOTAL:", total_orders, "GMV:", gmv)
except Exception as e:
    print(e)
