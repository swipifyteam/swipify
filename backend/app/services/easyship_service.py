import httpx
from typing import Dict, Any, Optional
from app.config import get_settings
import hmac
import hashlib
import json

settings = get_settings()

EASYSHIP_API_URL = "https://api.easyship.com/2023-01"

async def create_easyship_shipment(order_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Creates a shipment in Easyship using the API.
    order_data should contain destination, origin, items, and selected courier.
    """
    if not settings.SHIPAPI_KEY:
        raise ValueError("Easyship API key not configured")

    headers = {
        "Authorization": f"Bearer {settings.SHIPAPI_KEY}",
        "Content-Type": "application/json"
    }

    # Construct the Easyship shipment payload based on their API spec
    # This is a realistic representation of what the API expects
    payload = {
        "origin_address": order_data.get("origin_address"),
        "destination_address": order_data.get("destination_address"),
        "incoterms": "DDU",
        "insurance": {"is_insured": False},
        "courier_selection": {
            "selected_courier_id": order_data.get("courier_id")
        },
        "shipping_settings": {
            "units": {"weight": "kg", "dimensions": "cm"}
        },
        "parcels": [
            {
                "total_actual_weight": order_data.get("total_weight", 1.0),
                "box": {"slug": "custom"},
                "items": order_data.get("items", [])
            }
        ]
    }

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{EASYSHIP_API_URL}/shipments",
            headers=headers,
            json=payload,
            timeout=15.0
        )
        
        if response.status_code not in (200, 201):
            # Log error details for debugging but raise a standard exception
            print(f"[EASYSHIP API ERROR] {response.status_code}: {response.text}")
            raise Exception(f"Failed to create Easyship shipment: {response.text}")
            
        data = response.json()
        shipment = data.get("shipment", {})
        
        return {
            "shipment_id": shipment.get("easyship_shipment_id"),
            "tracking_number": shipment.get("tracking_page_url", "").split("/")[-1] if shipment.get("tracking_page_url") else "PENDING",
            "courier": shipment.get("courier", {}).get("name", "Unknown"),
            "label_url": shipment.get("label_url", "")
        }

def validate_easyship_webhook(payload_body: bytes, signature_header: str) -> bool:
    """
    Validates the incoming webhook from Easyship using HMAC-SHA256.
    """
    if not settings.SHIPAPI_KEY:
        return False
        
    # Standard webhook validation: compute HMAC and compare
    expected_signature = hmac.new(
        key=settings.SHIPAPI_KEY.encode('utf-8'),
        msg=payload_body,
        digestmod=hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(expected_signature, signature_header)
