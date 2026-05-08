import uuid
from datetime import datetime, timezone
from firebase_client import db, firestore # Assuming firebase_client exists and has db
from app.models.voucher import (
    VoucherCreateRequest, 
    VoucherResponse, 
    VoucherApplyRequest, 
    VoucherApplyResponse,
    VoucherAvailableRequest,
    VoucherUpdateRequest,
    VoucherClaimRequest,
    VoucherClaimResponse
)
from fastapi import HTTPException

def get_current_time_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def create_voucher_service(voucher_data: VoucherCreateRequest) -> VoucherResponse:
    vouchers_ref = db.collection("vouchers")
    
    # Check if code is unique (system-wide or per-seller)
    # For marketplace, usually codes are unique across the platform
    existing_query = vouchers_ref.where("code", "==", voucher_data.code).get()
    if existing_query:
        raise HTTPException(status_code=400, detail="Voucher code already exists")

    voucher_id = str(uuid.uuid4())
    now = get_current_time_iso()
    
    voucher_dict = voucher_data.dict()
    voucher_dict["id"] = voucher_id
    voucher_dict["used_count"] = 0
    voucher_dict["claimed_count"] = 0
    voucher_dict["remaining_quantity"] = voucher_data.usage_limit # usage_limit acts as total_quantity initially
    voucher_dict["total_quantity"] = voucher_data.usage_limit
    voucher_dict["created_at"] = now
    voucher_dict["start_date"] = voucher_data.start_date.isoformat()
    voucher_dict["end_date"] = voucher_data.end_date.isoformat()

    vouchers_ref.document(voucher_id).set(voucher_dict)
    print(f"[VOUCHER CREATED] {voucher_id} by {voucher_data.seller_id}")
    
    return VoucherResponse(**voucher_dict)

def update_voucher_service(voucher_id: str, update_data: VoucherUpdateRequest) -> VoucherResponse:
    voucher_ref = db.collection("vouchers").document(voucher_id)
    v_snap = voucher_ref.get()
    if not v_snap.exists:
        raise HTTPException(status_code=404, detail="Voucher not found")
    
    v = v_snap.to_dict()
    update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
    
    if "start_date" in update_dict and isinstance(update_dict["start_date"], datetime):
        update_dict["start_date"] = update_dict["start_date"].isoformat()
    if "end_date" in update_dict and isinstance(update_dict["end_date"], datetime):
        update_dict["end_date"] = update_dict["end_date"].isoformat()
        
    # If limit increases, update remaining_quantity
    if "usage_limit" in update_dict:
        new_limit = update_dict["usage_limit"]
        old_limit = v.get("usage_limit", 0)
        diff = new_limit - old_limit
        if diff > 0:
            update_dict["remaining_quantity"] = v.get("remaining_quantity", 0) + diff
            update_dict["total_quantity"] = new_limit

    voucher_ref.update(update_dict)
    updated_doc = voucher_ref.get().to_dict()
    return VoucherResponse(**updated_doc)

def delete_voucher_service(voucher_id: str):
    voucher_ref = db.collection("vouchers").document(voucher_id)
    if not voucher_ref.get().exists:
        raise HTTPException(status_code=404, detail="Voucher not found")
    voucher_ref.delete()
    print(f"[VOUCHER DELETED] {voucher_id}")

def get_seller_vouchers_service(seller_id: str) -> list[VoucherResponse]:
    vouchers_ref = db.collection("vouchers")
    docs = vouchers_ref.where("seller_id", "==", seller_id).get()
    results = []
    for doc in docs:
        try:
            v = doc.to_dict()
            results.append(VoucherResponse(**{**v, "id": doc.id}))
        except Exception as e:
            print(f"[VOUCHER PARSE SKIP] {doc.id}: {e}")
    return results

def claim_voucher_service(request: VoucherClaimRequest) -> VoucherClaimResponse:
    voucher_ref = db.collection("vouchers").document(request.voucher_id)
    user_claim_ref = db.collection("users").document(request.user_id).collection("claimed_vouchers").document(request.voucher_id)

    @firestore.transactional
    def atomic_claim(transaction, voucher_ref, user_claim_ref):
        v_snap = voucher_ref.get(transaction=transaction)
        if not v_snap.exists:
            raise HTTPException(status_code=404, detail="Voucher not found")
        
        v = v_snap.to_dict()
        
        # 1. Check if user already claimed
        claim_snap = user_claim_ref.get(transaction=transaction)
        if claim_snap.exists:
            raise HTTPException(status_code=400, detail="You have already claimed this voucher")

        # 2. Check stock/quantity
        remaining = v.get("remaining_quantity", v.get("usage_limit", 0))
        if remaining <= 0:
            raise HTTPException(status_code=400, detail="Voucher fully claimed")

        # 3. Check activity/expiry
        if not v.get("is_active", True):
            raise HTTPException(status_code=400, detail="Voucher is inactive")
        
        now = datetime.now(timezone.utc)
        end_date = datetime.fromisoformat(v["end_date"])
        if end_date.tzinfo is None: end_date = end_date.replace(tzinfo=timezone.utc)
        if now > end_date:
            raise HTTPException(status_code=400, detail="Voucher expired")

        # 4. Perform atomic updates
        transaction.update(voucher_ref, {
            "remaining_quantity": remaining - 1,
            "claimed_count": v.get("claimed_count", 0) + 1
        })
        
        transaction.set(user_claim_ref, {
            "voucher_id": request.voucher_id,
            "claimed_at": get_current_time_iso(),
            "is_used": False,
            "code": v.get("code")
        })
        
        return v

    try:
        transaction = db.transaction()
        voucher_data = atomic_claim(transaction, voucher_ref, user_claim_ref)
        
        # Build response
        voucher_data["is_claimed"] = True
        return VoucherClaimResponse(
            success=True,
            message="Voucher claimed successfully!",
            voucher=VoucherResponse(**voucher_data)
        )
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[CLAIM ERROR] {e}")
        return VoucherClaimResponse(success=False, message=str(e))

def apply_voucher_service(apply_data: VoucherApplyRequest) -> VoucherApplyResponse:
    # First, verify the user has CLAIMED this voucher
    if not apply_data.user_id:
        raise HTTPException(status_code=401, detail="User authentication required to apply vouchers")

    vouchers_ref = db.collection("vouchers")
    
    # Query by code (or ID if we wanted, but codes are user-friendly)
    query = vouchers_ref.where("code", "==", apply_data.voucher_code.upper()).limit(1).get()
    
    if not query:
        raise HTTPException(status_code=404, detail="Invalid voucher code")
    
    voucher_doc = query[0]
    v = voucher_doc.to_dict()
    v_id = voucher_doc.id

    # Check ownership record
    user_claim_ref = db.collection("users").document(apply_data.user_id).collection("claimed_vouchers").document(v_id)
    claim_snap = user_claim_ref.get()
    
    if not claim_snap.exists:
        raise HTTPException(status_code=400, detail="You must claim this voucher before using it")
    
    claim_data = claim_snap.to_dict()
    if claim_data.get("is_used"):
        raise HTTPException(status_code=400, detail="You have already used this voucher")
    
    # Check if voucher is store-specific
    if v.get("seller_id") and v["seller_id"] != apply_data.seller_id and v["seller_id"] != "system":
        raise HTTPException(status_code=400, detail="Voucher not applicable for this shop")

    # Time and logic validation
    if not v["is_active"]:
        raise HTTPException(status_code=400, detail="Voucher is inactive")
    
    now = datetime.now(timezone.utc)
    end_date = datetime.fromisoformat(v["end_date"])
    if end_date.tzinfo is None: end_date = end_date.replace(tzinfo=timezone.utc)
    if now > end_date:
        raise HTTPException(status_code=400, detail="Voucher expired")
        
    if apply_data.cart_total < v["minimum_spend"]:
        raise HTTPException(status_code=400, detail=f"Minimum order of ₱{v['minimum_spend']} not reached")

    # Calculation
    discount = 0.0
    target = v.get("discount_target", "SUBTOTAL")
    base_amount = apply_data.cart_total if target == "SUBTOTAL" else (apply_data.shipping_fee or 0.0)
    
    if v["discount_type"] == "percentage":
        discount = base_amount * (v["discount_value"] / 100)
        if v.get("max_discount"):
            discount = min(discount, v["max_discount"])
    else: # fixed
        discount = v["discount_value"]
        
    discount = min(discount, base_amount)
    
    final_total = (apply_data.cart_total + (apply_data.shipping_fee or 0.0)) - discount
    
    print(f"[VOUCHER VALIDATED] Code: {v['code']}, Discount: {discount}")
    
    return VoucherApplyResponse(
        discount=round(discount, 2),
        final_total=round(final_total, 2),
        voucher_id=v_id,
        code=v["code"]
    )

def list_active_vouchers_service(user_id: str = None) -> list[VoucherResponse]:
    vouchers_ref = db.collection("vouchers")
    now = datetime.now(timezone.utc)
    
    docs = vouchers_ref.where("is_active", "==", True).get()
    
    # If user_id provided, get their claims to mark 'is_claimed'
    claimed_ids = set()
    if user_id:
        claims = db.collection("users").document(user_id).collection("claimed_vouchers").get()
        claimed_ids = {c.id for c in claims if not c.to_dict().get("is_used", False)}

    active_vouchers = []
    for doc in docs:
        v = doc.to_dict()
        # Expiry check
        end_date = datetime.fromisoformat(v["end_date"])
        if end_date.tzinfo is None: end_date = end_date.replace(tzinfo=timezone.utc)
        if now > end_date: continue
        
        # Stock check
        if v.get("remaining_quantity", 0) <= 0: continue

        v_id = doc.id
        v_ready = {
            **v,
            "id": v_id,
            "is_claimed": v_id in claimed_ids
        }
        # Ensure all required fields exist for VoucherResponse
        active_vouchers.append(VoucherResponse(**v_ready))
            
    return active_vouchers

def get_available_vouchers_service(request: VoucherAvailableRequest) -> list[VoucherResponse]:
    """Get vouchers that the user has CLAIMED and are applicable to current cart."""
    if not request.user_id:
        return []

    # 1. Get user's claimed but unused vouchers
    claims = db.collection("users").document(request.user_id).collection("claimed_vouchers").where("is_used", "==", False).get()
    if not claims:
        return []

    claimed_voucher_ids = [c.id for c in claims]
    
    # 2. Fetch actual voucher details
    # Firestore 'in' query limit is 30, so we might need chunks if user has many claims
    vouchers_ref = db.collection("vouchers")
    v_docs = vouchers_ref.where(firestore.FieldPath.document_id(), "in", claimed_voucher_ids[:30]).get()

    available = []
    now = datetime.now(timezone.utc)
    
    for doc in v_docs:
        v = doc.to_dict()
        if not v.get("is_active"): continue
        
        # Expiry
        end_date = datetime.fromisoformat(v["end_date"])
        if end_date.tzinfo is None: end_date = end_date.replace(tzinfo=timezone.utc)
        if now > end_date: continue

        # Seller applicability
        s_id = v.get("seller_id", "system")
        if s_id != "system" and s_id not in request.seller_ids:
            continue
            
        # Min order
        cart_total = request.cart_totals.get(s_id, 0.0) if s_id != "system" else sum(request.cart_totals.values())
        if cart_total < v.get("minimum_spend", 0.0):
            continue
            
        available.append(VoucherResponse(**{**v, "id": doc.id, "is_claimed": True}))

    return available

def finalize_voucher_usage_service(user_id: str, voucher_id: str):
    """Marks a voucher as used in the user's collection and increments global usage."""
    user_claim_ref = db.collection("users").document(user_id).collection("claimed_vouchers").document(voucher_id)
    voucher_ref = db.collection("vouchers").document(voucher_id)

    @firestore.transactional
    def mark_used(transaction, u_ref, v_ref):
        u_snap = u_ref.get(transaction=transaction)
        if not u_snap.exists or u_snap.to_dict().get("is_used"):
            return # Already used or not claimed
            
        transaction.update(u_ref, {"is_used": True, "used_at": get_current_time_iso()})
        transaction.update(v_ref, {"used_count": firestore.Increment(1)})

    transaction = db.transaction()
    mark_used(transaction, user_claim_ref, voucher_ref)
