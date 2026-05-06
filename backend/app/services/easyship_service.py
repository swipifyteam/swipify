import httpx
from typing import Dict, Any, Optional
from app.config import get_settings
import json

settings = get_settings()

EASYSHIP_API_URL = "https://api.easyship.com/2023-01"

# Status Mapping as requested by the user
STATUS_MAPPING = {
    "shipment.created": "label_created",
    "shipment.in_transit": "shipped",
    "shipment.out_for_delivery": "out_for_delivery",
    "shipment.delivered": "delivered",
    "shipment.failed": "exception"
}

async def create_easyship_shipment(order_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Creates a shipment in Easyship using the API.
    order_data should contain destination, origin, items, and selected courier.
    Supports COD flag and payment status validation.
    """
    if not settings.SHIPAPI_KEY:
        raise ValueError("Easyship API key not configured")

    headers = {
        "Authorization": f"Bearer {settings.SHIPAPI_KEY}",
        "Content-Type": "application/json"
    }

    # Determine COD
    is_cod = order_data.get("payment_method") == "COD"
    
    # Construct the Easyship shipment payload
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
        ],
        # COD support
        "order_data": {
            "buyer_selected_courier_id": order_data.get("courier_id"),
            "order_number": order_data.get("order_id"),
        }
    }

    if is_cod:
        payload["shipping_settings"]["additional_services"] = ["cash_on_delivery"]
        # Easyship typically requires total_declared_value for COD
        payload["total_declared_value"] = order_data.get("total_price", 0)

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{EASYSHIP_API_URL}/shipments",
                headers=headers,
                json=payload,
                timeout=20.0
            )
            
            if response.status_code not in (200, 201):
                error_msg = response.text
                print(f"[EASYSHIP API ERROR] {response.status_code}: {error_msg}")
                raise Exception(f"Easyship API Failure: {error_msg}")
                
            data = response.json()
            shipment = data.get("shipment", {})
            
            if not shipment:
                 raise Exception("Invalid response from Easyship: Missing shipment data")

            tracking_number = shipment.get("tracking_number")
            if not tracking_number:
                # Some couriers generate tracking numbers later, but we need one or a placeholder
                tracking_number = shipment.get("easyship_shipment_id", "PENDING")

            return {
                "shipment_id": shipment.get("easyship_shipment_id"),
                "tracking_number": tracking_number,
                "courier": shipment.get("courier", {}).get("name", "Unknown"),
                "label_url": shipment.get("label_url", ""),
                "status": "label_created"
            }
        except httpx.RequestError as e:
            print(f"[EASYSHIP REQUEST ERROR] {str(e)}")
            raise Exception(f"Failed to connect to Easyship API: {str(e)}")

def validate_webhook_key(header_key: str) -> bool:
    """
    Validates the incoming webhook using the x-api-key header.
    """
    if not settings.APIWEB_KEY:
        print("[EASYSHIP WEBHOOK] ⚠️ APIWEB_KEY not configured in backend!")
        return False
    return header_key == settings.APIWEB_KEY

def map_easyship_event_to_status(event_type: str) -> str:
    """
    Maps Easyship event types to internal order statuses.
    """
    return STATUS_MAPPING.get(event_type, "shipped")
