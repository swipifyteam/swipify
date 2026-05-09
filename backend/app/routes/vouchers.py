from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional
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
from app.utils.auth_utils import get_current_user, verify_owner

router = APIRouter()

@router.get("", response_model=List[VoucherResponse])
async def get_all_active_vouchers(token: dict = Depends(get_current_user)):
    """Fetch all active available vouchers for display. Marks is_claimed for the current user."""
    try:
        return list_active_vouchers_service(token["uid"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/claim", response_model=VoucherClaimResponse)
async def claim_voucher(request: VoucherClaimRequest, token: dict = Depends(get_current_user)):
    """Atomic voucher claim for the authenticated user."""
    verify_owner(request.user_id, token["uid"])
    try:
        return claim_voucher_service(request)
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/available", response_model=AvailableVouchersResponse)
async def get_available_vouchers(request: VoucherAvailableRequest, token: dict = Depends(get_current_user)):
    """Fetch applicable vouchers that the user has ALREADY CLAIMED."""
    verify_owner(request.user_id, token["uid"])
    try:
        vouchers = get_available_vouchers_service(request)
        return AvailableVouchersResponse(vouchers=vouchers)
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/apply-voucher", response_model=VoucherApplyResponse)
async def apply_voucher(request: VoucherApplyRequest, token: dict = Depends(get_current_user)):
    """Apply a voucher. Checks for claim ownership and validity."""
    verify_owner(request.user_id, token["uid"])
    try:
        return apply_voucher_service(request)
    except HTTPException as e:
        return VoucherApplyResponse(
            discount=0.0,
            final_total=request.cart_total,
            voucher_id="",
            code=request.voucher_code,
            message=e.detail
        )
    except Exception as e:
        return VoucherApplyResponse(
            discount=0.0,
            final_total=request.cart_total,
            voucher_id="",
            code=request.voucher_code,
            message="Internal Server Error"
        )
