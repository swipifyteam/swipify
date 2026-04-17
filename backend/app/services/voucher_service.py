import uuid
from datetime import datetime, timezone
from firebase_client import db, firestore # Assuming firebase_client exists and has db
from app.models.voucher import (
    VoucherCreateRequest, 
    VoucherResponse, 
    VoucherApplyRequest, 
    VoucherApplyResponse,
    VoucherAvailableRequest,
    VoucherUpdateRequest
)
from fastapi import HTTPException

def get_current_time_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def create_voucher_service(voucher_data: VoucherCreateRequest) -> VoucherResponse:
    vouchers_ref = db.collection("seller_vouchers")
    
    # Check if code is unique for this seller
    existing_query = vouchers_ref.where("seller_id", "==", voucher_data.seller_id).where("code", "==", voucher_data.code).get()
    if existing_query:
        raise HTTPException(status_code=400, detail="Voucher code already exists for this seller")

    voucher_id = str(uuid.uuid4())
    now = get_current_time_iso()
    
    voucher_dict = voucher_data.dict()
    voucher_dict["id"] = voucher_id
    voucher_dict["used_count"] = 0
    voucher_dict["created_at"] = now
    # Convert datetimes to strings for storage
    voucher_dict["start_date"] = voucher_data.start_date.isoformat()
    voucher_dict["end_date"] = voucher_data.end_date.isoformat()

    vouchers_ref.document(voucher_id).set(voucher_dict)
    print(f"[VOUCHER CREATED] {voucher_id} by {voucher_data.seller_id}")
    
    return VoucherResponse(**voucher_dict)

def get_seller_vouchers_service(seller_id: str) -> list[VoucherResponse]:
    vouchers_ref = db.collection("seller_vouchers")
    docs = vouchers_ref.where("seller_id", "==", seller_id).get()
    results = []
    for doc in docs:
        try:
            v = doc.to_dict()
            # Defensive default for older vouchers missing discount_target
            if "discount_target" not in v:
                v["discount_target"] = "SUBTOTAL"
            results.append(VoucherResponse(**v))
        except Exception as e:
            print(f"[VOUCHER PARSE SKIP] {doc.id}: {e}")
    return results

def apply_voucher_service(apply_data: VoucherApplyRequest) -> VoucherApplyResponse:
    vouchers_ref = db.collection("seller_vouchers")
    
    # Query by code and seller
    query = vouchers_ref.where("seller_id", "==", apply_data.seller_id).where("code", "==", apply_data.voucher_code.upper()).limit(1).get()
    
    if not query:
        raise HTTPException(status_code=404, detail="Invalid voucher")
    
    voucher_doc = query[0]
    v = voucher_doc.to_dict()
    
    # Validation
    if not v["is_active"]:
        raise HTTPException(status_code=400, detail="Voucher is no longer active")
    
    now = datetime.now(timezone.utc)
    
    # Time window validation (Robust)
    start_date = datetime.fromisoformat(v["start_date"])
    if start_date.tzinfo is None:
        start_date = start_date.replace(tzinfo=timezone.utc)
        
    end_date = datetime.fromisoformat(v["end_date"])
    if end_date.tzinfo is None:
        end_date = end_date.replace(tzinfo=timezone.utc)
    
    if now < start_date:
        raise HTTPException(status_code=400, detail="Voucher has not started yet")
        
    if now > end_date:
        raise HTTPException(status_code=400, detail="Voucher expired")
        
    if v["used_count"] >= v["usage_limit"]:
        raise HTTPException(status_code=400, detail="Voucher limit reached")
        
    if apply_data.cart_total < v["min_order_amount"]:
        raise HTTPException(status_code=400, detail=f"Minimum order of ₱{v['min_order_amount']} not reached")

    # Calculation
    discount = 0.0
    target = v.get("discount_target", "SUBTOTAL")
    
    # Baseline for discount calculation
    base_amount = apply_data.cart_total if target == "SUBTOTAL" else (apply_data.shipping_fee or 0.0)
    
    if v["discount_type"] == "percentage":
        discount = base_amount * (v["discount_value"] / 100)
        if v.get("max_discount"):
            discount = min(discount, v["max_discount"])
    else: # fixed
        discount = v["discount_value"]
        
    # Ensure discount doesn't exceed the target amount
    discount = min(discount, base_amount)
    
    # Calculate final total based on target
    if target == "SUBTOTAL":
        final_subtotal = apply_data.cart_total - discount
        final_shipping = apply_data.shipping_fee or 0.0
    else: # SHIPPING
        final_subtotal = apply_data.cart_total
        final_shipping = (apply_data.shipping_fee or 0.0) - discount
        
    final_total = final_subtotal + final_shipping
    
    print(f"[VOUCHER APPLIED] Code: {v['code']}, Target: {target}, Discount: {discount}")
    
    return VoucherApplyResponse(
        discount=round(discount, 2),
        final_total=round(final_total, 2),
        voucher_id=v["id"],
        code=v["code"]
    )

def increment_voucher_usage_service(voucher_id: str):
    voucher_ref = db.collection("seller_vouchers").document(voucher_id)
    
    @firestore.transactional
    def update_in_transaction(transaction, voucher_ref):
        snapshot = voucher_ref.get(transaction=transaction)
        if not snapshot.exists:
            return
        
        current_used = snapshot.get("used_count")
        limit = snapshot.get("usage_limit")
        
        if current_used < limit:
            transaction.update(voucher_ref, {"used_count": current_used + 1})
            print(f"[VOUCHER USED] {voucher_id}")
            
    transaction = db.transaction()
    update_in_transaction(transaction, voucher_ref)

def get_available_vouchers_service(request: VoucherAvailableRequest) -> list[VoucherResponse]:
    vouchers_ref = db.collection("seller_vouchers")
    now = datetime.now(timezone.utc)

    available_vouchers = []

    docs = vouchers_ref.where("seller_id", "in", request.seller_ids).where("is_active", "==", True).get()

    for doc in docs:
        try:
            v = doc.to_dict()
            if not v:
                continue

            # 1. Expiry Check (timezone-safe)
            end_date_str = v.get("end_date")
            if not end_date_str:
                continue
            end_date = datetime.fromisoformat(end_date_str)
            if end_date.tzinfo is None:
                end_date = end_date.replace(tzinfo=timezone.utc)
            if now > end_date:
                continue

            # 2. Usage Limit Check
            if v.get("used_count", 0) >= v.get("usage_limit", 999999):
                continue

            # 3. Minimum Order Check
            s_id = v.get("seller_id", "")
            cart_total = request.cart_totals.get(s_id, 0.0)
            if cart_total < v.get("min_order_amount", 0.0):
                continue

            # 4. Build safe response dict with defaults
            start_date_str = v.get("start_date") or now.isoformat()
            v_ready = {
                "id": v.get("id", doc.id),
                "seller_id": s_id or "system",
                "code": v.get("code", "UNKNOWN"),
                "discount_type": v.get("discount_type", "fixed"),
                "discount_target": v.get("discount_target", "SUBTOTAL"),
                "discount_value": v.get("discount_value", 0.0),
                "min_order_amount": v.get("min_order_amount", 0.0),
                "max_discount": v.get("max_discount"),
                "usage_limit": v.get("usage_limit", 1),
                "used_count": v.get("used_count", 0),
                "start_date": start_date_str,
                "end_date": end_date_str,
                "scope": v.get("scope", "STORE"),
                "is_active": v.get("is_active", True),
                "created_at": v.get("created_at", now.isoformat()),
            }
            available_vouchers.append(VoucherResponse(**v_ready))
        except Exception as e:
            print(f"[VOUCHER SKIP] Error parsing voucher {doc.id}: {e}")
            continue

    return available_vouchers

def list_active_vouchers_service() -> list[VoucherResponse]:
    """Retrieve all active vouchers across all sellers."""
    vouchers_ref = db.collection("seller_vouchers")
    now = datetime.now(timezone.utc)
    
    try:
        docs = vouchers_ref.where("is_active", "==", True).get()
    except Exception as e:
        print(f"[FIRESTORE ERROR] {e}")
        return []
        
    active_vouchers = []
    
    for doc in docs:
        try:
            v = doc.to_dict()
            if not v:
                continue
            
            # 1. Expiry Check (Robust)
            end_date_str = v.get("end_date")
            if not end_date_str:
                continue
                
            end_date = datetime.fromisoformat(end_date_str)
            if end_date.tzinfo is None:
                end_date = end_date.replace(tzinfo=timezone.utc)
                
            if now > end_date:
                continue
                
            # 2. Usage Limit Check
            if v.get("used_count", 0) >= v.get("usage_limit", 999999):
                continue
                
            # 3. Model Compatibility (Defaults for missing fields)
            v_ready = {
                "id": v.get("id", doc.id),
                "seller_id": v.get("seller_id", "system"),
                "code": v.get("code", "UNKNOWN"),
                "discount_type": v.get("discount_type", "fixed"),
                "discount_target": v.get("discount_target", "SUBTOTAL"),
                "discount_value": v.get("discount_value", 0.0),
                "min_order_amount": v.get("min_order_amount", 0.0),
                "max_discount": v.get("max_discount"),
                "usage_limit": v.get("usage_limit", 1),
                "used_count": v.get("used_count", 0),
                "start_date": v.get("start_date", now.isoformat()),
                "end_date": v.get("end_date", now.isoformat()),
                "scope": v.get("scope", "STORE"),
                "is_active": v.get("is_active", True),
                "created_at": v.get("created_at", now.isoformat())
            }
            
            active_vouchers.append(VoucherResponse(**v_ready))
        except Exception as e:
            print(f"[VOUCHER SKIP] Error parsing voucher {doc.id}: {e}")
            continue
            
    return active_vouchers

def update_voucher_service(voucher_id: str, update_data: VoucherUpdateRequest) -> VoucherResponse:
    voucher_ref = db.collection("seller_vouchers").document(voucher_id)
    snapshot = voucher_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Voucher not found")
    
    update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
    
    if "start_date" in update_dict and isinstance(update_dict["start_date"], datetime):
        update_dict["start_date"] = update_dict["start_date"].isoformat()
    if "end_date" in update_dict and isinstance(update_dict["end_date"], datetime):
        update_dict["end_date"] = update_dict["end_date"].isoformat()
        
    voucher_ref.update(update_dict)
    
    updated_doc = voucher_ref.get().to_dict()
    return VoucherResponse(**updated_doc)

def delete_voucher_service(voucher_id: str):
    voucher_ref = db.collection("seller_vouchers").document(voucher_id)
    if not voucher_ref.get().exists:
        raise HTTPException(status_code=404, detail="Voucher not found")
    voucher_ref.delete()
    print(f"[VOUCHER DELETED] {voucher_id}")
