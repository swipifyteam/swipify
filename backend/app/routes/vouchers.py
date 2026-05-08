from fastapi import APIRouter, HTTPException
from app.models.voucher import (
    VoucherResponse, 
    VoucherApplyRequest, 
    VoucherApplyResponse, 
    VoucherAvailableRequest, 
    AvailableVouchersResponse,
    VoucherClaimRequest,
    VoucherClaimResponse
)
from app.services.voucher_service import (
    list_active_vouchers_service,
    apply_voucher_service,
    get_available_vouchers_service,
    claim_voucher_service,
)
from pydantic import BaseModel
from typing import List, Optional

router = APIRouter()

@router.get("", response_model=List[VoucherResponse])
async def get_all_active_vouchers(user_id: Optional[str] = None):
    """Fetch all active available vouchers for display. If user_id provided, marks is_claimed."""
    try:
        return list_active_vouchers_service(user_id)
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/claim", response_model=VoucherClaimResponse)
async def claim_voucher(request: VoucherClaimRequest):
    """Atomic voucher claim for a specific user."""
    try:
        return claim_voucher_service(request)
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[VOUCHER CLAIM ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/available", response_model=AvailableVouchersResponse)
async def get_available_vouchers(request: VoucherAvailableRequest):
    """Fetch applicable vouchers that the user has ALREADY CLAIMED."""
    try:
        if not request.user_id:
             raise HTTPException(status_code=401, detail="User ID required")
        vouchers = get_available_vouchers_service(request)
        return AvailableVouchersResponse(vouchers=vouchers)
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[VOUCHER AVAILABLE ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/apply-voucher", response_model=VoucherApplyResponse)
async def apply_voucher(request: VoucherApplyRequest):
    """Apply a voucher. Checks for claim ownership and validity."""
    try:
        return apply_voucher_service(request)
    except HTTPException as e:
        print(f"[VOUCHER VALIDATION] {e.detail}")
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
