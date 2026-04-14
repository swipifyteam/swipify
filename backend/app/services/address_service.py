# backend/app/services/address_service.py

import uuid
from datetime import datetime, timezone
from firebase_client import db, firestore # Import firestore for transactions
from app.models.address import AddressCreateRequest, AddressUpdateRequest

def get_current_time_iso() -> str:
    """Utility to get the current timestamp in ISO 8601 format."""
    return datetime.now(timezone.utc).isoformat()

def create_address_service(address_data: AddressCreateRequest) -> dict:
    """Creates a new address for a user, handling default address logic transactionally."""
    
    transaction = db.transaction()
    address_collection_ref = db.collection("users").document(address_data.user_id).collection("addresses")
    
    @firestore.transactional
    def create_address_transaction(transaction, address_collection_ref, address_data):
        address_id = str(uuid.uuid4())
        now = get_current_time_iso()

        new_address_dict = address_data.dict()
        new_address_dict["id"] = address_id
        new_address_dict["created_at"] = now
        new_address_dict["updated_at"] = now

        # Logic to handle setting an address as default.
        # Ensure only one address is default for the user.
        if new_address_dict["is_default"]:
            # Unset any existing default address for this user
            default_query = address_collection_ref.where("is_default", "==", True).get(transaction=transaction)
            for doc in default_query:
                transaction.update(doc.reference, {"is_default": False, "updated_at": now})
        else:
            # If no default is explicitly set, and this is the first address, make it default.
            existing_addresses_docs = address_collection_ref.limit(1).get(transaction=transaction)
            if not existing_addresses_docs: # If no addresses exist, this is the first one
                new_address_dict["is_default"] = True

        transaction.set(address_collection_ref.document(address_id), new_address_dict)
        return new_address_dict
    
    return create_address_transaction(transaction, address_collection_ref, address_data)


def get_user_addresses_service(user_id: str) -> list[dict]:
    """Retrieves all addresses for a given user."""
    addresses_ref = db.collection("users").document(user_id).collection("addresses")
    docs = addresses_ref.order_by("created_at").get()
    return [doc.to_dict() for doc in docs]


def update_address_service(user_id: str, address_id: str, address_data: AddressUpdateRequest) -> dict:
    """Updates an existing address, handling default address logic transactionally."""
    
    transaction = db.transaction()
    address_doc_ref = db.collection("users").document(user_id).collection("addresses").document(address_id)

    @firestore.transactional
    def update_address_transaction(transaction, address_doc_ref, address_data):
        address_doc = address_doc_ref.get(transaction=transaction)
        if not address_doc.exists:
            raise ValueError(f"Address {address_id} not found for user {user_id}")

        update_dict = address_data.dict(exclude_unset=True)
        now = get_current_time_iso()
        update_dict["updated_at"] = now

        # Handle is_default logic if provided in update_data
        if address_data.is_default is True:
            # Unset any existing default address for this user, excluding the current one
            addresses_ref = db.collection("users").document(user_id).collection("addresses")
            default_query = addresses_ref.where("is_default", "==", True).get(transaction=transaction)
            for doc in default_query:
                if doc.id != address_id:
                    transaction.update(doc.reference, {"is_default": False, "updated_at": now})
        
        transaction.update(address_doc_ref, update_dict)
        updated_doc = address_doc_ref.get(transaction=transaction)
        return updated_doc.to_dict()

    return update_address_transaction(transaction, address_doc_ref, address_data)


def delete_address_service(user_id: str, address_id: str):
    """Deletes an address for a user."""
    address_doc_ref = db.collection("users").document(user_id).collection("addresses").document(address_id)
    address_doc = address_doc_ref.get()
    if not address_doc.exists:
        raise ValueError(f"Address {address_id} not found for user {user_id}")
    
    address_doc_ref.delete()


def set_default_address_service(user_id: str, address_id: str) -> dict:
    """Sets a specific address as the default for a user, handling default address logic transactionally."""
    
    transaction = db.transaction()
    address_doc_ref = db.collection("users").document(user_id).collection("addresses").document(address_id)
    addresses_ref = db.collection("users").document(user_id).collection("addresses")

    @firestore.transactional
    def set_default_address_transaction(transaction, address_doc_ref, addresses_ref):
        target_address_doc = address_doc_ref.get(transaction=transaction)
        if not target_address_doc.exists:
            raise ValueError(f"Address {address_id} not found for user {user_id}")
        
        now = get_current_time_iso()

        # Unset any existing default address for this user (more robust without limit(1))
        default_query = addresses_ref.where("is_default", "==", True).get(transaction=transaction)
        for doc in default_query:
            if doc.id != address_id: # Only update if it's a different address
                transaction.update(doc.reference, {"is_default": False, "updated_at": now})
        
        # Set the target address as default
        transaction.update(address_doc_ref, {"is_default": True, "updated_at": now})
        
        updated_doc = address_doc_ref.get(transaction=transaction)
        return updated_doc.to_dict()

    return set_default_address_transaction(transaction, address_doc_ref, addresses_ref)