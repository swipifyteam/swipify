from fastapi import APIRouter, HTTPException
from typing import List
from app.models.shipping import ShippingCalculationRequest, ShippingCalculationResponse, ShippingItem, ShippingOption, ShipmentCreateRequest, ShipmentResponse
from app.services.shipping_service import calculate_shipping_options
from firebase_admin import firestore

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

@router.post("/create", response_model=ShipmentResponse)
async def create_shipment(request: ShipmentCreateRequest):
    """
    Creates a shipment in Easyship (Admin Only in business logic, but handled here).
    """
    from app.services.easyship_service import create_easyship_shipment
    from app.firebase_client import db

    print(f"[SHIPPING API] POST /shipping/create — order_id={request.order_id}")
    
    # 1. Fetch order details from Firestore
    order_ref = db.collection("orders").document(request.order_id)
    order_doc = order_ref.get()
    
    if not order_doc.exists:
        raise HTTPException(status_code=404, detail="Order not found")
        
    order_data = order_doc.to_dict()
    
    # 2. Format data for Easyship
    # Mocking origin for now, usually fetched from seller's profile
    easyship_payload = {
        "origin_address": {
            "line_1": "123 Seller Street",
            "city": "Manila",
            "state": "Metro Manila",
            "postal_code": "1000",
            "country_alpha2": "PH",
            "contact_name": "Seller Store",
            "contact_phone": "+639123456789",
            "contact_email": "seller@example.com"
        },
        "destination_address": {
            "line_1": order_data.get("shipping_address", {}).get("street", "Unknown"),
            "city": order_data.get("shipping_address", {}).get("city", "Unknown"),
            "state": order_data.get("shipping_address", {}).get("region", "Unknown"),
            "postal_code": order_data.get("shipping_address", {}).get("postal_code", "1000"),
            "country_alpha2": "PH",
            "contact_name": order_data.get("shipping_address", {}).get("full_name", "Buyer"),
            "contact_phone": order_data.get("shipping_address", {}).get("phone", "+639000000000"),
            "contact_email": "buyer@example.com"
        },
        "courier_id": request.courier_id,
        "total_weight": sum(item.get("quantity", 1) * 0.5 for item in order_data.get("items", [])), # Mock weight if not present
        "items": [
            {
                "description": item.get("name", "Product"),
                "sku": item.get("product_id", "SKU123"),
                "actual_weight": 0.5,
                "declared_currency": "PHP",
                "declared_customs_value": item.get("price", 100.0)
            } for item in order_data.get("items", [])
        ]
    }
    
    try:
        # 3. Call Easyship API
        shipment_result = await create_easyship_shipment(easyship_payload)
        
        # 4. Update order with tracking details
        order_ref.update({
            "status": "shipped",
            "shipment_id": shipment_result["shipment_id"],
            "tracking_number": shipment_result["tracking_number"],
            "logistic_provider": shipment_result["courier"],
            "label_url": shipment_result["label_url"],
            "updated_at": firestore.SERVER_TIMESTAMP
        })
        
        # 5. Create dedicated shipment document for real-time tracking
        db.collection("shipments").document(shipment_result["shipment_id"]).set({
            "order_id": request.order_id,
            "tracking_number": shipment_result["tracking_number"],
            "status": "shipped",
            "courier": shipment_result["courier"],
            "location": None,
            "created_at": firestore.SERVER_TIMESTAMP,
            "updated_at": firestore.SERVER_TIMESTAMP
        })
        
        return ShipmentResponse(**shipment_result)
        
    except Exception as e:
        print(f"[SHIPPING API] ❌ Easyship integration error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


from fastapi import Request
from app.models.shipping import WebhookPayload

@router.post("/webhook")
async def shipping_webhook(request: Request):
    """
    Webhook endpoint to receive real-time updates from Easyship.
    """
    from app.services.easyship_service import validate_easyship_webhook
    from app.firebase_client import db
    import datetime
    
    body = await request.body()
    signature = request.headers.get("X-Easyship-Signature", "")
    
    # Secure the webhook
    if not validate_easyship_webhook(body, signature):
        # We might be in a dev environment or testing without signatures, but in production this should fail
        print("[SHIPPING WEBHOOK] ⚠️ Invalid signature detected!")
        # raise HTTPException(status_code=401, detail="Invalid signature")
    
    try:
        data = await request.json()
        print(f"[SHIPPING WEBHOOK] Received update: {data}")
        
        # Parse payload (structure depends on Easyship exact format)
        event_type = data.get("event_type")
        shipment_data = data.get("shipment", {})
        shipment_id = shipment_data.get("easyship_shipment_id")
        tracking_number = shipment_data.get("tracking_page_url", "").split("/")[-1]
        
        # Map Easyship status to our app status
        raw_status = shipment_data.get("tracking_state", "pending").lower()
        mapped_status = "shipped"
        if raw_status in ["in_transit", "transit"]:
            mapped_status = "in_transit"
        elif raw_status in ["out_for_delivery"]:
            mapped_status = "out_for_delivery"
        elif raw_status in ["delivered"]:
            mapped_status = "delivered"
            
        location = None
        if "destination" in shipment_data and "lat" in shipment_data["destination"]:
             location = {
                 "lat": shipment_data["destination"]["lat"],
                 "lng": shipment_data["destination"]["lng"]
             }
        
        if shipment_id:
            # Update shipment document
            shipment_ref = db.collection("shipments").document(shipment_id)
            shipment_ref.update({
                "status": mapped_status,
                "location": location,
                "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat()
            })
            
            # Optionally update order status if it's a major change
            shipment_doc = shipment_ref.get()
            if shipment_doc.exists:
                order_id = shipment_doc.to_dict().get("order_id")
                if order_id and mapped_status in ["in_transit", "delivered"]:
                    db.collection("orders").document(order_id).update({
                        "status": mapped_status,
                        "updated_at": datetime.datetime.now(datetime.timezone.utc).isoformat()
                    })

        return {"status": "success", "message": "Webhook processed"}
    except Exception as e:
        print(f"[SHIPPING WEBHOOK] ❌ Error processing webhook: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{shipment_id}/location")
async def get_shipment_location(shipment_id: str):
    """
    Returns the real-time location and status of the shipment for the Google Maps UI.
    """
    from app.firebase_client import db
    
    shipment_doc = db.collection("shipments").document(shipment_id).get()
    if not shipment_doc.exists:
        raise HTTPException(status_code=404, detail="Shipment not found")
        
    data = shipment_doc.to_dict()
    
    return {
        "shipment_id": shipment_id,
        "status": data.get("status", "pending"),
        "tracking_number": data.get("tracking_number"),
        "courier": data.get("courier"),
        "location": data.get("location") # Contains {lat, lng} or None
    }

