from firebase_client import db
from datetime import datetime, timedelta, UTC
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
            
            now = datetime.now(UTC).replace(tzinfo=None)
            
            if doc.exists:
                data = doc.to_dict()
                last_updated = data.get("last_updated")
                
                # Handle Firestore Timestamp, ISO string, or datetime object
                if hasattr(last_updated, "to_datetime"):
                    last_updated_dt = last_updated.to_datetime()
                elif isinstance(last_updated, datetime):
                    last_updated_dt = last_updated
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
            "support_tickets": 0,
            "active_campaigns": 0,
            "total_disputes": 0
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
                db.collection("users").where("role", "==", "seller")
            )
            
            stats["pending_seller_approvals"] = await get_count(
                db.collection("sellers").where("status", "==", "PENDING")
            )
            
            # Order calculations
            orders_ref = db.collection("orders").select(["status", "total_price", "refund_requested", "created_at"]).stream()
            gmv = 0.0
            total_orders = 0
            refund_requests = 0

            now = datetime.now(UTC).replace(tzinfo=None)
            weekly_revenue = [0.0, 0.0, 0.0, 0.0]

            for doc in orders_ref:
                data = doc.to_dict()
                total_orders += 1
                status = data.get("status")
                price = float(data.get("total_price", 0.0))
                
                # GMV calculation: only completed or delivered
                if status in ["completed", "delivered"]:
                    gmv += price
                    
                    created_at = data.get("created_at")
                    if created_at:
                        if hasattr(created_at, "to_datetime"):
                            dt = created_at.to_datetime().replace(tzinfo=None)
                        elif isinstance(created_at, str):
                            try:
                                dt = datetime.fromisoformat(created_at.replace('Z', '+00:00')).replace(tzinfo=None)
                            except ValueError:
                                dt = None
                        else:
                            dt = None
                        
                        if dt:
                            days_ago = (now - dt).days
                            if 0 <= days_ago < 28:
                                week_idx = 3 - (days_ago // 7)
                                weekly_revenue[week_idx] += (price * 0.05)
                
                # Refund requests: status == refunded OR refund_requested == true
                if status == "refunded" or data.get("refund_requested") is True:
                    refund_requests += 1

            stats["total_orders"] = total_orders
            stats["gmv"] = gmv
            stats["platform_revenue"] = gmv * 0.05
            stats["refund_requests"] = refund_requests
            stats["weekly_revenue"] = weekly_revenue
            
            stats["active_listings"] = await get_count(
                db.collection("products").where("status", "==", "active")
            )
            
            stats["pending_products"] = await get_count(
                db.collection("products").where("status", "==", "pending")
            )
            
            stats["support_tickets"] = await get_count(
                db.collection("support_tickets").where("status", "==", "open")
            )
            
            # Marketing Stats (Active Campaigns)
            now = datetime.now(UTC).replace(tzinfo=None)
            active_count = 0
            
            # Count active platform vouchers
            platform_vouchers = db.collection("vouchers").get()
            for doc in platform_vouchers:
                v = doc.to_dict()
                end = v.get("end_date") or v.get("expiryDate")
                if end:
                    try:
                        if hasattr(end, "to_datetime"):
                            end_dt = end.to_datetime().replace(tzinfo=None)
                        else:
                            end_dt = datetime.fromisoformat(str(end).split('Z')[0]).replace(tzinfo=None)
                        if end_dt > now:
                            active_count += 1
                    except Exception:
                        pass
                else:
                    active_count += 1 # No expiry means active
            
            # Count active seller vouchers
            seller_vouchers = db.collection("seller_vouchers").get()
            for doc in seller_vouchers:
                v = doc.to_dict()
                end = v.get("end_date")
                if end:
                    try:
                        end_dt = datetime.fromisoformat(str(end).split('Z')[0]).replace(tzinfo=None)
                        if end_dt > now:
                            active_count += 1
                    except Exception:
                        pass
                else:
                    active_count += 1
            
            stats["active_campaigns"] = active_count
            
            # Disputes count
            stats["total_disputes"] = await get_count(db.collection("disputes"))

        except Exception as e:
            logger.error(f"Error computing stats: {str(e)}")
            
        return stats
