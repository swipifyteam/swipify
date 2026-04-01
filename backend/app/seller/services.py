# app/seller/services.py
# Business logic for Seller endpoints

from firebase_client import db
import firebase_admin
from app.seller.schemas import SellerApplicationRequest, SellerStatusEnum
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from app.utils.notifications import create_notification
import uuid

def get_seller_status(user_id: str):
    """"Fetch seller status for a given user."""
    # query 'sellers' collection for this user_id
    docs = db.collection("sellers").where("userId", "==", user_id).limit(1).get()
    if len(docs) == 0:
        return {"status": SellerStatusEnum.NOT_APPLIED, "seller": None}
    
    seller = docs[0].to_dict()
    seller["id"] = docs[0].id
    status = seller.get("status", SellerStatusEnum.PENDING)
    
    return {"status": status, "seller": seller}

def apply_seller(data: SellerApplicationRequest):
    """"Create a new seller application, store identity images, and update user status."""
    docs = db.collection("sellers").where("userId", "==", data.user_id).limit(1).get()
    if len(docs) > 0:
        return False, "You have already applied."

    seller_id = str(uuid.uuid4())
    seller_data = {
        "userId": data.user_id,
        "storeName": data.store_name,
        "sellerType": data.seller_type,
        "status": SellerStatusEnum.PENDING,
        "identity_image_url": data.identity_image_url,
        "selfie_image_url": data.selfie_image_url,
        "createdAt": SERVER_TIMESTAMP,
        "updatedAt": SERVER_TIMESTAMP
    }
    
    # ── SAVE SELLER APPLICATION (FIRESTORE) ──────────────────────────────────
    db.collection("sellers").document(seller_id).set(seller_data)
    
    # Save bank info
    bank_id = str(uuid.uuid4())
    db.collection("bank_details").document(bank_id).set({
        "sellerId": seller_id,
        "bankName": data.bank_name,
        "accountNumber": data.account_number
    })
    
    # ── UPDATE USER STATUS REACTIVITY ─────────────────────────────────────
    # [SELLER] Status set to PENDING in the global user record.
    db.collection("users").document(data.user_id).set({
        "seller_status": SellerStatusEnum.PENDING,
        "updatedAt": SERVER_TIMESTAMP
    }, merge=True)
    
    debugmsg = f"[SELLER] Application created for {data.user_id}. Status: PENDING."
    print(debugmsg)
    
    seller_data["id"] = seller_id
    return True, seller_data

from app.utils.cloudinary_handler import upload_image_to_cloudinary
import uuid

def upload_document(seller_id: str, doc_type: str, file_bytes: bytes, filename: str, content_type: str):
    """"Uploads an image to Cloudinary and saves URL to Firestore."""
    # Verify seller exists (Lookup by userId if direct doc fails)
    seller_ref = db.collection("sellers").document(seller_id)
    doc = seller_ref.get()
    
    # If not found by ID (which is a UUID), try searching by userId field
    if not doc.exists:
        docs = db.collection("sellers").where("userId", "==", seller_id).limit(1).get()
        if len(docs) == 0:
            return False, "Seller not found"
        seller_ref = docs[0].reference
        doc = docs[0]

    try:
        # ── CLOUDINARY UPLOAD (REPLACES FIREBASE STORAGE) ─────────────────────
        folder = "seller_docs" if doc_type != "product_image" else "products"
        file_url = upload_image_to_cloudinary(file_bytes, filename, folder=folder)
        
        if not file_url:
            return False, "Failed to get secure URL from Cloudinary"
            
    except Exception as e:
        print(f"[UPLOAD] Cloudinary failure: {e}")
        return False, f"Upload error: {str(e)}"

    # Save to Firestore
    doc_id = str(uuid.uuid4())
    db.collection("seller_documents").document(doc_id).set({
        "sellerId": seller_id,
        "type": doc_type,
        "fileUrl": file_url,
        "uploadedAt": SERVER_TIMESTAMP
    })

    return True, file_url

def approve_seller(seller_id: str):
    """"Approve a seller application."""
    seller_ref = db.collection("sellers").document(seller_id)
    doc = seller_ref.get()

    # Search by userId field if direct ID lookup fails
    if not doc.exists:
        docs = db.collection("sellers").where("userId", "==", seller_id).limit(1).get()
        if len(docs) == 0:
            return False, "Seller not found"
        seller_ref = docs[0].reference
        doc = docs[0]
    
    seller_ref.update({
        "status": SellerStatusEnum.APPROVED,
        "updatedAt": SERVER_TIMESTAMP
    })
    
    seller = doc.to_dict()
    uid = seller.get("userId")
    store_name = seller.get("storeName", "New Shop")
    
    # ── CREATE SHOP DOCUMENT (STRICT: Link to User UID) ──────────────────────
    if uid:
        # Create the shop
        db.collection("shops").document(uid).set({
            "owner_id": uid,
            "shop_name": store_name,
            "is_active": True,
            "created_at": SERVER_TIMESTAMP,
            "description": f"Welcome to {store_name}!",
            "logo_url": None,
            "banner_url": None,
            "shipping_settings": {
                "fee": 50,
                "regions": ["NCR", "Luzon"],
                "estimated_days": "3-5 days"
            }
        })
        
        # Update global user status for reactive sync (SAFE SET: create if missing)
        db.collection("users").document(uid).set({
            "uid": uid,
            "seller_status": SellerStatusEnum.APPROVED,
            "role": "seller",
            "shop_id": uid,
            "updatedAt": SERVER_TIMESTAMP
        }, merge=True)
        print(f"[SHOP] Shop created for {uid} with name '{store_name}'")

    # Notify user
    create_notification(uid, "You're now a seller 🎉", "Your shop has been approved. Start selling now!", "SELLER_APPROVED")
    
    return True, "Seller approved and shop created"

def reject_seller(seller_id: str, reason: str = None):
    """"Reject a seller application."""
    seller_ref = db.collection("sellers").document(seller_id)
    doc = seller_ref.get()

    # Search by userId field if direct ID lookup fails
    if not doc.exists:
        docs = db.collection("sellers").where("userId", "==", seller_id).limit(1).get()
        if len(docs) == 0:
            return False, "Seller not found"
        seller_ref = docs[0].reference
        doc = docs[0]
    
    seller_ref.update({
        "status": SellerStatusEnum.REJECTED,
        "updatedAt": SERVER_TIMESTAMP
    })
    
    seller = doc.to_dict()
    uid = seller.get("userId")

    # Update global user status for reactive sync
    if uid:
        db.collection("users").document(uid).update({
            "seller_status": SellerStatusEnum.REJECTED
        })

    msg = "Your seller application was not approved. " + (f"Reason: {reason}" if reason else "Please check your details and try again.")
    # Notify user
    create_notification(uid, "⚠️ Seller Application Update", msg, "SELLER_REJECTED")
    
    return True, "Seller rejected"
