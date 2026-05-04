from fastapi import APIRouter, Request, HTTPException, Header
from app.services.easyship_service import validate_webhook_key, map_easyship_event_to_status
from firebase_client import db
from firebase_admin import firestore
import datetime

router = APIRouter()

@router.post("/easyship")
async def easyship_webhook(
    request: Request, 
    x_api_key: str = Header(None, alias="x-api-key")
):
    """
    Secure webhook endpoint for Easyship tracking updates.
    Validates using APIWEB_KEY and updates database with live status.
    """
    # 1. Security Validation
    if not validate_webhook_key(x_api_key):
        print(f"[WEBHOOK] ❌ Unauthorized access attempt with key: {x_api_key}")
        raise HTTPException(status_code=401, detail="Unauthorized")

    try:
        data = await request.json()
        event_type = data.get("event_type")
        shipment_data = data.get("shipment", {})
        shipment_id = shipment_data.get("easyship_shipment_id")
        event_id = data.get("event_id") # For idempotency

        if not shipment_id:
            return {"status": "ignored", "reason": "No shipment ID found"}

        print(f"[WEBHOOK] Received {event_type} for Shipment {shipment_id}")

        # 2. Idempotency Check (Prevent duplicate processing)
        if event_id:
            event_ref = db.collection("processed_events").document(event_id)
            if event_ref.get().exists:
                print(f"[WEBHOOK] ⚠️ Event {event_id} already processed. Skipping.")
                return {"status": "success", "message": "Already processed"}
            event_ref.set({"processed_at": firestore.SERVER_TIMESTAMP})

        # 3. Map status
        mapped_status = map_easyship_event_to_status(event_type)
        
        # Extract location if available
        last_location = "Unknown"
        checkpoint = shipment_data.get("last_checkpoint", {})
        if checkpoint:
            city = checkpoint.get("city", "")
            country = checkpoint.get("country_name", "")
            last_location = f"{city}, {country}" if city and country else (city or country or "In Transit")

        # 4. Update Shipment Document
        shipment_ref = db.collection("shipments").document(shipment_id)
        shipment_update = {
            "status": mapped_status,
            "last_location": last_location,
            "last_updated_timestamp": firestore.SERVER_TIMESTAMP,
            "raw_easyship_status": shipment_data.get("tracking_state"),
            "updated_at": firestore.SERVER_TIMESTAMP
        }
        
        # Add ETA if available
        eta = shipment_data.get("min_delivery_time") or shipment_data.get("max_delivery_time")
        if eta:
            shipment_update["estimated_arrival"] = eta

        shipment_ref.update(shipment_update)

        # 5. Sync to Order Document
        shipment_doc = shipment_ref.get()
        if shipment_doc.exists:
            order_id = shipment_doc.to_dict().get("order_id")
            if order_id:
                order_ref = db.collection("orders").document(order_id)
                
                # Update order status and add to status history
                order_update = {
                    "status": mapped_status,
                    "updated_at": firestore.SERVER_TIMESTAMP
                }
                
                # Update tracking info in order doc too for redundancy/easy access
                order_update["tracking_status"] = mapped_status
                
                order_ref.update(order_update)
                
                # Add status history entry
                status_history_entry = {
                    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    "old_status": "unknown", # Could fetch old status but trying to minimize reads
                    "new_status": mapped_status,
                    "updated_by": "easyship_webhook",
                    "notes": f"Location: {last_location}"
                }
                order_ref.update({
                    "status_history": firestore.ArrayUnion([status_history_entry])
                })

        return {"status": "success", "message": "Shipment updated"}

    except Exception as e:
        print(f"[WEBHOOK ERROR] ❌ {str(e)}")
        # We return 200 even on some errors to prevent Easyship from retrying broken payloads indefinitely, 
        # but here we'll raise 500 for actual server issues.
        raise HTTPException(status_code=500, detail=str(e))
