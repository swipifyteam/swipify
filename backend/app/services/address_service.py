
import uuid
from datetime import datetime, timezone
from firebase_client import db, firestore
from app.models.address import AddressCreateRequest, AddressUpdateRequest, AddressResponse

def get_current_time_iso() -> str:
    """Utility to get the current timestamp in ISO 8601 format."""
    return datetime.now(timezone.utc).isoformat()

def create_address_service(address_data: AddressCreateRequest) -> AddressResponse:
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

        if new_address_dict["is_default"]:
            default_query = address_collection_ref.where("is_default", "==", True).get(transaction=transaction)
            for doc in default_query:
                transaction.update(doc.reference, {"is_default": False, "updated_at": now})
        else:
            existing_addresses_docs = address_collection_ref.limit(1).get(transaction=transaction)
            if not existing_addresses_docs:
                new_address_dict["is_default"] = True

        transaction.set(address_collection_ref.document(address_id), new_address_dict)
        return AddressResponse(**new_address_dict)
    
    return create_address_transaction(transaction, address_collection_ref, address_data)


def get_user_addresses_service(user_id: str) -> list[AddressResponse]: # Reverted type hint
    """Retrieves all addresses for a given user."""
    addresses_ref = db.collection("users").document(user_id).collection("addresses")
    docs = addresses_ref.order_by("created_at").get()
    return [AddressResponse(**doc.to_dict()) for doc in docs]


def update_address_service(user_id: str, address_id: str, address_data: AddressUpdateRequest) -> AddressResponse: # Reverted type hint
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

        if update_dict.get("is_default") is True:
            addresses_ref = db.collection("users").document(user_id).collection("addresses")
            default_query = addresses_ref.where("is_default", "==", True).get(transaction=transaction)
            for doc in default_query:
                if doc.id != address_id:
                    transaction.update(doc.reference, {"is_default": False, "updated_at": now})
        
        transaction.update(address_doc_ref, update_dict)
        updated_doc = address_doc_ref.get(transaction=transaction)
        return AddressResponse(**updated_doc.to_dict())

    return update_address_transaction(transaction, address_doc_ref, address_data)


def delete_address_service(user_id: str, address_id: str):
    """Deletes an address for a user."""
    address_doc_ref = db.collection("users").document(user_id).collection("addresses").document(address_id)
    address_doc = address_doc_ref.get()
    if not address_doc.exists:
        raise ValueError(f"Address {address_id} not found for user {user_id}")
    
    address_doc_ref.delete()


def set_default_address_service(user_id: str, address_id: str) -> AddressResponse: # Reverted type hint
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

        default_query = addresses_ref.where("is_default", "==", True).get(transaction=transaction)
        for doc in default_query:
            if doc.id != address_id:
                transaction.update(doc.reference, {"is_default": False, "updated_at": now})
        
        transaction.update(address_doc_ref, {"is_default": True, "updated_at": now})
        
        updated_doc = address_doc_ref.get(transaction=transaction)
        return AddressResponse(**updated_doc.to_dict())

    return set_default_address_transaction(transaction, address_doc_ref, addresses_ref)
