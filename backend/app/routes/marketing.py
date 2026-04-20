from fastapi import APIRouter, HTTPException
from typing import List
from app.models.marketing import (
    FlashSaleCreateRequest, FlashSaleResponse,
    BundleDealCreateRequest, BundleDealResponse,
    LoyaltyConfigSaveRequest, LoyaltyConfigResponse
)
from app.services.marketing_service import MarketingService

router = APIRouter(prefix="/marketing", tags=["Marketing"])

# --- FLASH SALES ---
@router.post("/flash-sales", response_model=FlashSaleResponse)
async def create_flash_sale(req: FlashSaleCreateRequest):
    try:
        return await MarketingService.create_flash_sale(req.model_dump())
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/flash-sales/{seller_id}", response_model=List[FlashSaleResponse])
async def get_flash_sales(seller_id: str):
    return await MarketingService.get_seller_flash_sales(seller_id)

@router.delete("/flash-sales/{sale_id}")
async def delete_flash_sale(sale_id: str):
    await MarketingService.delete_flash_sale(sale_id)
    return {"message": "Flash sale deleted"}

# --- BUNDLE DEALS ---
@router.post("/bundle-deals", response_model=BundleDealResponse)
async def create_bundle_deal(req: BundleDealCreateRequest):
    try:
        return await MarketingService.create_bundle_deal(req.model_dump())
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/bundle-deals/{seller_id}", response_model=List[BundleDealResponse])
async def get_bundle_deals(seller_id: str):
    return await MarketingService.get_seller_bundle_deals(seller_id)

@router.delete("/bundle-deals/{bundle_id}")
async def delete_bundle_deal(bundle_id: str):
    await MarketingService.delete_bundle_deal(bundle_id)
    return {"message": "Bundle deal deleted"}

# --- LOYALTY POINTS ---
@router.post("/loyalty/config", response_model=LoyaltyConfigResponse)
async def save_loyalty_config(req: LoyaltyConfigSaveRequest):
    try:
        return await MarketingService.save_loyalty_config(req.model_dump())
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/loyalty/config/{seller_id}", response_model=LoyaltyConfigResponse)
async def get_loyalty_config(seller_id: str):
    return await MarketingService.get_loyalty_config(seller_id)
