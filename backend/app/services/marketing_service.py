from firebase_client import db
from datetime import datetime
import uuid

class MarketingService:
    # --- FLASH SALES ---
    @staticmethod
    async def create_flash_sale(data: dict):
        sale_id = str(uuid.uuid4())
        data["id"] = sale_id
        data["sold_count"] = 0
        data["created_at"] = datetime.now().isoformat()
        
        # Convert datetime objects to strings if they are present and are datetime objects
        if "start_time" in data and isinstance(data["start_time"], datetime):
            data["start_time"] = data["start_time"].isoformat()
        if "end_time" in data and isinstance(data["end_time"], datetime):
            data["end_time"] = data["end_time"].isoformat()
            
        db.collection("flash_sales").document(sale_id).set(data)
        return data

    @staticmethod
    async def get_seller_flash_sales(seller_id: str):
        docs = db.collection("flash_sales").where("seller_id", "==", seller_id).stream()
        return [doc.to_dict() for doc in docs]

    @staticmethod
    async def delete_flash_sale(sale_id: str):
        db.collection("flash_sales").document(sale_id).delete()
        return True

    # --- BUNDLE DEALS ---
    @staticmethod
    async def create_bundle_deal(data: dict):
        bundle_id = str(uuid.uuid4())
        data["id"] = bundle_id
        data["created_at"] = datetime.now().isoformat()
        
        if "start_time" in data and isinstance(data["start_time"], datetime):
            data["start_time"] = data["start_time"].isoformat()
        if "end_time" in data and isinstance(data["end_time"], datetime):
            data["end_time"] = data["end_time"].isoformat()
            
        db.collection("bundle_deals").document(bundle_id).set(data)
        return data

    @staticmethod
    async def get_seller_bundle_deals(seller_id: str):
        docs = db.collection("bundle_deals").where("seller_id", "==", seller_id).stream()
        return [doc.to_dict() for doc in docs]

    @staticmethod
    async def delete_bundle_deal(bundle_id: str):
        db.collection("bundle_deals").document(bundle_id).delete()
        return True

    # --- LOYALTY POINTS ---
    @staticmethod
    async def save_loyalty_config(data: dict):
        seller_id = data["seller_id"]
        data["updated_at"] = datetime.now().isoformat()
        db.collection("loyalty_configs").document(seller_id).set(data)
        return data

    @staticmethod
    async def get_loyalty_config(seller_id: str):
        doc = db.collection("loyalty_configs").document(seller_id).get()
        if doc.exists:
            return doc.to_dict()
        # Default config
        return {
            "seller_id": seller_id,
            "points_per_peso": 0.01,
            "min_redeem_points": 10,
            "is_enabled": False,
            "updated_at": datetime.now().isoformat()
        }
