from fastapi import APIRouter, HTTPException, Depends
from app.models.voucher import VoucherCreateRequest, VoucherResponse, VoucherApplyRequest, VoucherApplyResponse
from app.services.voucher_service import (
    create_voucher_service,
    get_seller_vouchers_service,
    apply_voucher_service,
    get_available_vouchers_service,
    update_voucher_service,
    delete_voucher_service
)
from app.models.voucher import (
    VoucherCreateRequest, 
    VoucherResponse, 
    VoucherApplyRequest, 
    VoucherApplyResponse,
    VoucherAvailableRequest,
    VoucherUpdateRequest
)

router = APIRouter()

@router.post("/seller/vouchers", response_model=VoucherResponse)
async def create_voucher(request: VoucherCreateRequest):
    """Create a new voucher for a seller."""
    try:
        return create_voucher_service(request)
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/seller/vouchers/{seller_id}", response_model=list[VoucherResponse])
async def get_seller_vouchers(seller_id: str):
    """Retrieve all vouchers for a specific seller."""
    try:
        return get_seller_vouchers_service(seller_id)
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/voucher/apply", response_model=VoucherApplyResponse)
async def apply_voucher(request: VoucherApplyRequest):
    """Apply a seller voucher to a cart subtotal."""
    try:
        return apply_voucher_service(request)
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/vouchers/available", response_model=list[VoucherResponse])
async def get_available_vouchers(request: VoucherAvailableRequest):
    """Retrieve all valid and active vouchers for a checkout session."""
    try:
        return get_available_vouchers_service(request)
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/seller/vouchers/{voucher_id}", response_model=VoucherResponse)
async def update_voucher(voucher_id: str, request: VoucherUpdateRequest):
    """Update an existing voucher."""
    try:
        return update_voucher_service(voucher_id, request)
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/seller/vouchers/{voucher_id}")
async def delete_voucher(voucher_id: str):
    """Delete a voucher."""
    try:
        delete_voucher_service(voucher_id)
        return {"message": "Voucher deleted successfully"}
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"[VOUCHER ERROR] {e}")
        raise HTTPException(status_code=500, detail=str(e))
