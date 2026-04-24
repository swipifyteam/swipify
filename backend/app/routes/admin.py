from fastapi import APIRouter, HTTPException, Depends, Query
from firebase_client import db
from app.utils.auth_utils import require_admin, require_role
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from datetime import datetime, timedelta
from app.models.marketing import PlatformVoucherCreateRequest
from app.models.support import SupportActionRequest
from app.models.settings import PlatformSettingsUpdateRequest

router = APIRouter()

# MODULE 1 - COMMAND CENTER DASHBOARD
@router.get("/dashboard/stats")
async def get_dashboard_stats(user: dict = Depends(require_admin)):
    """Fetch live stats for admin dashboard."""
    try:
        # For a production app with large datasets, these should be aggregated via Cloud Functions or scheduled tasks
        # But for this MVP, we query Firestore (optimized as much as possible)
        
        # We can use count() for optimized fetching in firestore where available, but since we're using
        # standard client, let's fetch documents or rely on a generic aggregate collection if existed.
        # Given limitations, we'll fetch references and count them
        
        users_ref = db.collection("users").get()
        total_users = len(users_ref)
        
        sellers_query = db.collection("users").where("role", "==", "seller").get()
        total_sellers = len(sellers_query)
        
        orders_ref = db.collection("orders").get()
        total_orders = len(orders_ref)
        
        gmv = sum(doc.to_dict().get("total_price", 0) for doc in orders_ref if doc.to_dict().get("status") not in ["cancelled", "refunded"])
        platform_revenue = gmv * 0.05 # Assuming 5% commission
        
        # More advanced queries for "today"
        today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        
        # Pending Seller Approvals
        pending_sellers = db.collection("seller_applications").where("status", "==", "pending").get()
        
        # Refund Requests (Disputes or Refunded Orders)
        refund_requests = db.collection("disputes").where("status", "==", "pending").get()
        
        # Support Tickets
        open_tickets = db.collection("support_tickets").where("status", "==", "open").get()
        
        return {
            "total_users": total_users,
            "total_sellers": total_sellers,
            "total_orders": total_orders,
            "gmv": gmv,
            "platform_revenue": platform_revenue,
            "pending_seller_approvals": len(pending_sellers),
            "refund_requests": len(refund_requests),
            "support_tickets": len(open_tickets)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 2 - USER MANAGEMENT
@router.get("/users")
async def list_users(
    limit: int = 20, 
    offset: int = 0, 
    role: str = None, 
    search: str = None,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "support_admin"]))
):
    try:
        query = db.collection("users")
        
        if role:
            query = query.where("role", "==", role)
            
        docs = query.get()
        users = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            users.append(data)
            
        # Basic manual pagination/search since firestore text search is limited without external tools like Typesense/Algolia
        if search:
            search_lower = search.lower()
            users = [u for u in users if search_lower in str(u.get("name", "")).lower() or search_lower in str(u.get("email", "")).lower()]
            
        paginated = users[offset:offset+limit]
        
        return {
            "total": len(users),
            "users": paginated
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/users/{uid}/status")
async def update_user_status(
    uid: str, 
    status: str, # "active", "suspended", "banned"
    user: dict = Depends(require_role(["super_admin", "operations_admin"]))
):
    try:
        if status not in ["active", "suspended", "banned"]:
            raise HTTPException(status_code=400, detail="Invalid status")
            
        db.collection("users").document(uid).update({
            "status": status,
            "updated_at": SERVER_TIMESTAMP
        })
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": f"update_user_status",
            "target_uid": uid,
            "details": f"Status changed to {status}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True, "message": f"User status updated to {status}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/users/{uid}/role")
async def update_user_role(
    uid: str, 
    role: str,
    user: dict = Depends(require_role(["super_admin"]))
):
    try:
        db.collection("users").document(uid).update({
            "role": role,
            "updated_at": SERVER_TIMESTAMP
        })
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": f"update_user_role",
            "target_uid": uid,
            "details": f"Role changed to {role}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True, "message": f"User role updated to {role}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 3 - SELLER MANAGEMENT
@router.get("/sellers/applications")
async def list_seller_applications(
    limit: int = 20, 
    offset: int = 0, 
    status: str = "pending", # "pending", "approved", "rejected"
    user: dict = Depends(require_role(["super_admin", "operations_admin", "support_admin"]))
):
    try:
        # Assuming seller applications are stored in a `seller_applications` collection
        # Or it could be users with role="buyer" but has an application flag.
        # Let's use a `seller_applications` collection.
        query = db.collection("seller_applications").where("status", "==", status)
        docs = query.get()
        
        apps = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            apps.append(data)
            
        paginated = apps[offset:offset+limit]
        
        return {
            "total": len(apps),
            "applications": paginated
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/sellers/applications/{app_id}/approve")
async def approve_seller_application(
    app_id: str,
    user: dict = Depends(require_role(["super_admin", "operations_admin"]))
):
    try:
        app_ref = db.collection("seller_applications").document(app_id)
        doc = app_ref.get()
        
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Application not found")
            
        app_data = doc.to_dict()
        uid = app_data.get("user_id")
        
        if not uid:
            raise HTTPException(status_code=400, detail="Application missing user_id")
            
        # Update application status
        app_ref.update({
            "status": "approved",
            "approved_by": user["uid"],
            "updated_at": SERVER_TIMESTAMP
        })
        
        # Promote user to seller
        db.collection("users").document(uid).update({
            "role": "seller",
            "updated_at": SERVER_TIMESTAMP
        })
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": f"approve_seller",
            "target_uid": uid,
            "application_id": app_id,
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True, "message": "Seller application approved"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/sellers/applications/{app_id}/reject")
async def reject_seller_application(
    app_id: str,
    reason: str,
    user: dict = Depends(require_role(["super_admin", "operations_admin"]))
):
    try:
        app_ref = db.collection("seller_applications").document(app_id)
        
        if not app_ref.get().exists:
            raise HTTPException(status_code=404, detail="Application not found")
            
        # Update application status
        app_ref.update({
            "status": "rejected",
            "reject_reason": reason,
            "rejected_by": user["uid"],
            "updated_at": SERVER_TIMESTAMP
        })
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "reject_seller",
            "target_app_id": app_id,
            "details": f"Reason: {reason}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True, "message": "Seller application rejected"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 4 - PRODUCT MODERATION
@router.get("/products")
async def list_products(
    limit: int = 50,
    offset: int = 0,
    status: str = None, # "active", "hidden", "archived", "flagged"
    seller_id: str = None,
    category: str = None,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "moderator"]))
):
    try:
        query = db.collection("products")
        if status:
            query = query.where("status", "==", status)
        if seller_id:
            query = query.where("seller_id", "==", seller_id)
        if category:
            query = query.where("category", "==", category)
            
        docs = query.get()
        products = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            products.append(data)
            
        paginated = products[offset:offset+limit]
        return {
            "total": len(products),
            "products": paginated
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/products/{product_id}/status")
async def update_product_status(
    product_id: str,
    status: str, # "active", "hidden", "archived"
    reason: str = None,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "moderator"]))
):
    try:
        if status not in ["active", "hidden", "archived"]:
            raise HTTPException(status_code=400, detail="Invalid status")
            
        db.collection("products").document(product_id).update({
            "status": status,
            "moderation_reason": reason,
            "moderated_by": user["uid"],
            "updated_at": SERVER_TIMESTAMP
        })
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": f"update_product_status",
            "target_product": product_id,
            "details": f"Status changed to {status}. Reason: {reason}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True, "message": f"Product status updated to {status}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 5 - ORDER CONTROL CENTER
@router.get("/orders")
async def list_orders(
    limit: int = 50,
    offset: int = 0,
    status: str = None, 
    user_id: str = None,
    seller_id: str = None,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "support_admin", "finance_admin"]))
):
    try:
        query = db.collection("orders")
        if status:
            query = query.where("status", "==", status)
        if user_id:
            query = query.where("user_id", "==", user_id)
        if seller_id:
            query = query.where("seller_id", "==", seller_id)
            
        # Typically order by date, but requires composite index
        # query = query.order_by("created_at", direction=firestore.Query.DESCENDING)
            
        docs = query.get()
        orders = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            orders.append(data)
            
        # Basic sorting since no composite index
        orders.sort(key=lambda x: str(x.get("created_at", "")), reverse=True)
            
        paginated = orders[offset:offset+limit]
        return {
            "total": len(orders),
            "orders": paginated
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/orders/{order_id}/force-cancel")
async def force_cancel_order(
    order_id: str,
    reason: str,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "support_admin"]))
):
    try:
        order_ref = db.collection("orders").document(order_id)
        if not order_ref.get().exists:
            raise HTTPException(status_code=404, detail="Order not found")
            
        order_ref.update({
            "status": "cancelled",
            "cancel_reason": reason,
            "cancelled_by_admin": user["uid"],
            "updated_at": SERVER_TIMESTAMP
        })
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": f"force_cancel_order",
            "target_order": order_id,
            "details": f"Reason: {reason}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True, "message": "Order forcefully cancelled"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 6 - FINANCE CENTER
@router.get("/finance/overview")
async def finance_overview(
    user: dict = Depends(require_role(["super_admin", "finance_admin"]))
):
    try:
        # Simplistic finance calculation for MVP
        # Should be a scheduled aggregation in production
        orders_ref = db.collection("orders").get()
        
        total_gmv = 0
        platform_revenue = 0
        seller_payouts = 0
        refunds = 0
        
        for doc in orders_ref:
            data = doc.to_dict()
            status = data.get("status")
            price = data.get("total_price", 0)
            
            if status not in ["cancelled", "refunded"]:
                total_gmv += price
                platform_revenue += price * 0.05
                seller_payouts += price * 0.95
            elif status == "refunded":
                refunds += price
                
        return {
            "total_gmv": total_gmv,
            "net_platform_revenue": platform_revenue,
            "pending_seller_payouts": seller_payouts, # Assuming all are pending for simplicity
            "total_refunds": refunds
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 7 - MARKETING CENTER
@router.get("/marketing/vouchers")
async def list_platform_vouchers(user: dict = Depends(require_admin)):
    """List all platform-wide vouchers."""
    try:
        docs = db.collection("platform_vouchers").get()
        vouchers = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            # Convert timestamps to ISO strings
            for field in ["start_date", "end_date", "created_at"]:
                if field in data and hasattr(data[field], "isoformat"):
                    data[field] = data[field].isoformat()
            vouchers.append(data)
        return vouchers
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/marketing/vouchers")
async def create_platform_voucher(
    voucher_data: PlatformVoucherCreateRequest,
    user: dict = Depends(require_role(["super_admin", "marketing_admin"]))
):
    """Create a new platform-wide voucher."""
    try:
        # Check if code already exists
        existing = db.collection("platform_vouchers").where("code", "==", voucher_data.code.upper()).get()
        if existing:
            raise HTTPException(status_code=400, detail="Voucher code already exists")
            
        doc_data = voucher_data.dict()
        doc_data["code"] = doc_data["code"].upper()
        doc_data["usage_count"] = 0
        doc_data["created_at"] = SERVER_TIMESTAMP
        
        doc_ref = db.collection("platform_vouchers").add(doc_data)
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "create_platform_voucher",
            "details": f"Created voucher: {doc_data['code']}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"id": doc_ref[1].id, "success": True}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/marketing/vouchers/{voucher_id}")
async def delete_platform_voucher(
    voucher_id: str,
    user: dict = Depends(require_role(["super_admin", "marketing_admin"]))
):
    """Delete a platform-wide voucher."""
    try:
        voucher_ref = db.collection("platform_vouchers").document(voucher_id)
        if not voucher_ref.get().exists:
            raise HTTPException(status_code=404, detail="Voucher not found")
            
        voucher_ref.delete()
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "delete_platform_voucher",
            "target_id": voucher_id,
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/marketing/stats")
async def get_marketing_stats(user: dict = Depends(require_admin)):
    """Get global marketing performance stats."""
    try:
        vouchers = db.collection("platform_vouchers").get()
        total_vouchers = len(vouchers)
        total_redemptions = sum(doc.to_dict().get("usage_count", 0) for doc in vouchers)
        
        # For more complex stats, we'd query order history or a specific marketing_stats collection
        return {
            "total_vouchers": total_vouchers,
            "total_redemptions": total_redemptions,
            "active_campaigns": 0 # Placeholder for now
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 8 - SUPPORT & DISPUTES
@router.get("/support/tickets")
async def list_support_tickets(
    status: str = None,
    priority: str = None,
    user: dict = Depends(require_role(["super_admin", "support_admin"]))
):
    """List all support tickets with optional filtering."""
    try:
        query = db.collection("support_tickets")
        if status:
            query = query.where("status", "==", status)
        if priority:
            query = query.where("priority", "==", priority)
            
        docs = query.get()
        tickets = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            # Convert timestamps
            for field in ["created_at", "updated_at"]:
                if field in data and hasattr(data[field], "isoformat"):
                    data[field] = data[field].isoformat()
            tickets.append(data)
        return tickets
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/support/disputes")
async def list_disputes(
    status: str = None,
    user: dict = Depends(require_role(["super_admin", "support_admin", "finance_admin"]))
):
    """List all transaction disputes."""
    try:
        query = db.collection("disputes")
        if status:
            query = query.where("status", "==", status)
            
        docs = query.get()
        disputes = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            # Convert timestamps
            for field in ["created_at", "updated_at"]:
                if field in data and hasattr(data[field], "isoformat"):
                    data[field] = data[field].isoformat()
            disputes.append(data)
        return disputes
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/support/tickets/{ticket_id}")
async def update_ticket(
    ticket_id: str,
    action: SupportActionRequest,
    user: dict = Depends(require_role(["super_admin", "support_admin"]))
):
    """Update support ticket status, assignment or notes."""
    try:
        ticket_ref = db.collection("support_tickets").document(ticket_id)
        if not ticket_ref.get().exists:
            raise HTTPException(status_code=404, detail="Ticket not found")
            
        update_data = action.dict(exclude_none=True)
        update_data["updated_at"] = SERVER_TIMESTAMP
        
        ticket_ref.update(update_data)
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "update_support_ticket",
            "target_id": ticket_id,
            "details": f"Updated fields: {list(update_data.keys())}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/support/disputes/{dispute_id}/resolve")
async def resolve_dispute(
    dispute_id: str,
    resolution: str, # "refunded", "rejected"
    notes: str = None,
    user: dict = Depends(require_role(["super_admin", "support_admin"]))
):
    """Resolve a dispute with a final decision."""
    try:
        dispute_ref = db.collection("disputes").document(dispute_id)
        doc = dispute_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Dispute not found")
            
        dispute_data = doc.to_dict()
        order_id = dispute_data.get("order_id")
        
        status = f"resolved_{resolution}"
        
        dispute_ref.update({
            "status": status,
            "admin_notes": notes,
            "resolved_by": user["uid"],
            "resolved_at": SERVER_TIMESTAMP,
            "updated_at": SERVER_TIMESTAMP
        })
        
        # If refunded, we also need to update the order status
        if resolution == "refunded" and order_id:
            db.collection("orders").document(order_id).update({
                "status": "refunded",
                "refunded_at": SERVER_TIMESTAMP,
                "updated_at": SERVER_TIMESTAMP
            })
            
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "resolve_dispute",
            "target_id": dispute_id,
            "details": f"Resolution: {resolution}. Notes: {notes}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 9 - PLATFORM SETTINGS
@router.get("/settings")
async def get_platform_settings(user: dict = Depends(require_admin)):
    """Retrieve global platform configuration."""
    try:
        doc = db.collection("config").document("platform").get()
        if not doc.exists:
            # Return defaults if not set
            return {
                "commission_rate": 0.05,
                "payout_threshold": 50.0,
                "maintenance_mode": False,
                "allowed_categories": ["Electronics", "Fashion", "Home", "Beauty", "Sports"],
                "support_email": "support@swipify.com"
            }
        return doc.to_dict()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/settings")
async def update_platform_settings(
    settings: PlatformSettingsUpdateRequest,
    user: dict = Depends(require_role(["super_admin"]))
):
    """Update global platform configuration."""
    try:
        config_ref = db.collection("config").document("platform")
        
        update_data = settings.dict(exclude_none=True)
        update_data["updated_at"] = SERVER_TIMESTAMP
        update_data["updated_by"] = user["uid"]
        
        config_ref.set(update_data, merge=True)
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "update_platform_settings",
            "details": f"Updated settings: {list(update_data.keys())}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
