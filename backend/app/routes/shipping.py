from fastapi import APIRouter, HTTPException
from typing import List
from app.models.shipping import ShippingCalculationRequest, ShippingCalculationResponse, ShippingItem, ShippingOption
from app.services.shipping_service import calculate_shipping_options

router = APIRouter()

# Static list of available shipping options (before calculation)
STATIC_SHIPPING_OPTIONS = [
    {
        "id": "standard",
        "name": "Standard Shipping",
        "base_fee": 120.0,
        "estimated_delivery": "3-5 business days",
    },
    {
        "id": "express",
        "name": "Express Shipping",
        "base_fee": 170.0,
        "estimated_delivery": "1-2 business days",
    },
]

@router.get("/options")
async def get_shipping_options():
    """Returns the list of available shipping methods."""
    print("[SHIPPING API] GET /shipping/options")
    return STATIC_SHIPPING_OPTIONS

@router.post("/calculate", response_model=ShippingCalculationResponse)
async def calculate_shipping(request: ShippingCalculationRequest):
    """
    Calculate shipping options based on items and destination.
    """
    print(f"[SHIPPING API] POST /shipping/calculate — destination={request.destination_postal_code}, items={len(request.items)}")
    try:
        options = calculate_shipping_options(request.items, request.destination_postal_code)
        return ShippingCalculationResponse(options=options)
    except ValueError as e:
        print(f"[SHIPPING API] ❌ Validation error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"[SHIPPING API] ❌ Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
