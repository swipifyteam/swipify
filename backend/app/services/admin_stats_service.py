from firebase_client import db
from datetime import datetime, timedelta
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
import logging

logger = logging.getLogger(__name__)

class AdminStatsService:
    @staticmethod
    async def get_dashboard_stats():
        """Get cached dashboard stats or recompute if stale."""
        try:
            stats_ref = db.collection("admin_metadata").document("dashboard_stats")
            doc = stats_ref.get()
            
            now = datetime.utcnow()
            
            if doc.exists:
                data = doc.to_dict()
                last_updated = data.get("last_updated")
                
                # Handle Firestore Timestamp or ISO string
                if hasattr(last_updated, "to_datetime"):
                    last_updated_dt = last_updated.to_datetime()
                elif isinstance(last_updated, str):
                    last_updated_dt = datetime.fromisoformat(last_updated.replace('Z', '+00:00'))
                else:
                    last_updated_dt = None

                if last_updated_dt and (now - last_updated_dt.replace(tzinfo=None)) < timedelta(hours=1):
                    logger.info("Returning cached dashboard stats")
                    # Prepare for JSON response
                    if hasattr(last_updated, "isoformat"):
                        data["last_updated"] = last_updated.isoformat()
                    return data

            logger.info("Recomputing dashboard stats")
            stats = await AdminStatsService._compute_stats()
            stats["last_updated"] = SERVER_TIMESTAMP
            stats_ref.set(stats)
            
            # Prepare for JSON response
            stats["last_updated"] = now.isoformat()
            return stats
        except Exception as e:
            logger.error(f"Error getting dashboard stats: {str(e)}")
            # Fallback to computing live if cache fails
            return await AdminStatsService._compute_stats()

    @staticmethod
    async def _compute_stats():
        """Compute statistics from primary collections."""
        stats = {
            "total_users": 0,
            "total_sellers": 0,
            "total_orders": 0,
            "gmv": 0.0,
            "platform_revenue": 0.0,
            "pending_seller_approvals": 0,
            "refund_requests": 0,
            "support_tickets": 0
        }

        try:
            # Helper to get count safely
            async def get_count(query):
                try:
                    # Try optimized count() aggregation
                    results = query.count().get()
                    return results[0][0].value
                except Exception:
                    # Fallback to fetching all docs (expensive)
                    return len(query.get())

            stats["total_users"] = await get_count(db.collection("users"))
            
            stats["total_sellers"] = await get_count(
                db.collection("users").where("role", "==", "seller").where("sellerStatus", "==", "APPROVED")
            )
            
            stats["pending_seller_approvals"] = await get_count(
                db.collection("seller_applications").where("status", "==", "pending")
            )
            
            stats["total_orders"] = await get_count(db.collection("orders"))
            
            # GMV calculation (needs to fetch documents that are not cancelled/refunded)
            orders_ref = db.collection("orders").get()
            gmv = 0.0
            for doc in orders_ref:
                data = doc.to_dict()
                if data.get("status") not in ["cancelled", "refunded"]:
                    gmv += float(data.get("total_price", 0))
            
            stats["gmv"] = gmv
            stats["platform_revenue"] = gmv * 0.05
            
            stats["refund_requests"] = await get_count(
                db.collection("disputes").where("status", "==", "pending")
            )
            
            stats["support_tickets"] = await get_count(
                db.collection("support_tickets").where("status", "==", "open")
            )

        except Exception as e:
            logger.error(f"Error computing stats: {str(e)}")
            
        return stats
