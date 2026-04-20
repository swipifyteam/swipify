from fastapi import APIRouter, HTTPException
from app.models.voucher import VoucherResponse, VoucherApplyRequest, VoucherApplyResponse, VoucherAvailableRequest, AvailableVouchersResponse
from app.services.voucher_service import (
    list_active_vouchers_service,
    apply_voucher_service,
    get_available_vouchers_service,
)
from pydantic import BaseModel
from typing import List

router = APIRouter()

@router.get("", response_model=List[VoucherResponse])
async def get_all_active_vouchers():
    """Fetch all active available vouchers for display."""
    try:
        return list_active_vouchers_service()
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/available", response_model=AvailableVouchersResponse)
async def get_available_vouchers(request: VoucherAvailableRequest):
    """Fetch applicable vouchers for a checkout session filtered by seller IDs and cart totals."""
    try:
        # Guard against empty seller_ids (Firestore 'in' query requires at least 1 element)
        if not request.seller_ids:
            return AvailableVouchersResponse(vouchers=[])
        vouchers = get_available_vouchers_service(request)
        return AvailableVouchersResponse(vouchers=vouchers)
    except Exception as e:
        print(f"[VOUCHER AVAILABLE ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/apply-voucher", response_model=VoucherApplyResponse)
async def apply_voucher(request: VoucherApplyRequest):
    """
    Apply a voucher to a checkout session.
    Returns the discount and the updated total.
    """
    try:
        # Re-using the robust service logic from seller_vouchers
        # Ensure that VoucherApplyRequest model matches the frontend expectations
        return apply_voucher_service(request)
    except HTTPException as e:
        # Fallback as requested: invalid voucher -> discount = 0
        print(f"[VOUCHER VALIDATION] {e.detail}")
        # Note: Depending on frontend needs, we might return a 200 with 0 discount 
        # but usually 400 with detail is better. The user said "invalid voucher -> discount = 0" 
        # so I will return a success response with 0 discount if it's a validation error.
        
        # However, for genuine errors (404), we might want to be explicit.
        # I'll implement a safe wrapper.
        return VoucherApplyResponse(
            discount=0.0,
            final_total=request.cart_total,
            voucher_id="",
            code=request.voucher_code,
            message=e.detail
        )
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        return VoucherApplyResponse(
            discount=0.0,
            final_total=request.cart_total,
            voucher_id="",
            code=request.voucher_code,
            message="Internal Server Error"
        )
