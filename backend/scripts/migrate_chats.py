import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore

# Setup to allow imports from backend root
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def initialize_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "serviceAccountKey.json"))
        firebase_admin.initialize_app(cred)
    return firestore.client()

def migrate_chats():
    db = initialize_firebase()
    print("Starting chat migration...")
    
    chats_ref = db.collection('chats')
    chats = chats_ref.stream()
    
    updated_count = 0
    error_count = 0
    
    for chat in chats:
        data = chat.to_dict()
        chat_id = chat.id
        buyer_id = data.get('buyer_id')
        seller_id = data.get('seller_id')
        
        updates = {}
        
        if buyer_id:
            try:
                buyer_doc = db.collection('users').document(buyer_id).get()
                if buyer_doc.exists:
                    updates['buyer_name'] = buyer_doc.to_dict().get('name', 'Unknown User')
                else:
                    updates['buyer_name'] = 'Unknown User'
            except Exception as e:
                print(f"Error fetching buyer {buyer_id}: {e}")
                updates['buyer_name'] = 'Unknown User'
                
        if seller_id:
            try:
                seller_doc = db.collection('sellers').document(seller_id).get()
                if seller_doc.exists:
                    updates['seller_name'] = seller_doc.to_dict().get('storeName', 'Unknown Store')
                else:
                    updates['seller_name'] = 'Unknown Store'
            except Exception as e:
                print(f"Error fetching seller {seller_id}: {e}")
                updates['seller_name'] = 'Unknown Store'
                
        if updates:
            try:
                chats_ref.document(chat_id).update(updates)
                updated_count += 1
                print(f"Updated chat {chat_id} with {updates}")
            except Exception as e:
                print(f"Failed to update chat {chat_id}: {e}")
                error_count += 1
                
    print(f"Migration completed! Updated {updated_count} chats. Errors: {error_count}")

if __name__ == "__main__":
    migrate_chats()
