from firebase_client import db

def test_fetch():
    seller_id = "WmXnaKZ7qZXZx8KRKPKrfHXVCDp2"
    query = db.collection("products").where("seller_id", "==", seller_id).where("status", "!=", "archived")
    docs = query.get()
    products = []
    for doc in docs:
        p = doc.to_dict()
        p["id"] = doc.id
        products.append(p)
    print("Found", len(products), "products")
    
    try:
        products.sort(key=lambda x: str(x.get("created_at") or ""), reverse=True)
        print("Sort succeeded")
    except Exception as e:
        import traceback
        traceback.print_exc()
        
test_fetch()
