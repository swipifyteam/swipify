from fastapi import APIRouter, HTTPException, Depends, Query
from firebase_client import db
from app.utils.auth_utils import require_admin, require_role
from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from datetime import datetime, timedelta, UTC
from app.models.marketing import PlatformVoucherCreateRequest, PlatformVoucherUpdateRequest
from app.models.support import SupportActionRequest
from app.models.settings import PlatformSettingsUpdateRequest
from app.services.admin_stats_service import AdminStatsService
from app.seller.schemas import SellerStatusEnum
from app.seller.services import approve_seller as seller_svc_approve, reject_seller as seller_svc_reject
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


def batch_resolve_user_names(user_ids: list) -> dict:
    """Batch fetch user display_name/shop_name from multiple collections.
    Cascade: shops → sellers → users to ensure storeName is resolved.
    Returns {uid: {display_name, shop_name}} mapping.
    """
    if not user_ids:
        return {}
    
    unique_ids = list(set(uid for uid in user_ids if uid))
    result = {}
    
    # Firestore 'in' query supports max 30 items
    for i in range(0, len(unique_ids), 30):
        batch = unique_ids[i:i+30]
        
        # --- Layer 1: Users collection (base identity) ---
        try:
            docs = db.collection("users").where("__name__", "in",
                [db.collection("users").document(uid) for uid in batch]
            ).select(["display_name", "name", "shop_name", "email"]).get()
        except Exception:
            docs = []
            for uid in batch:
                try:
                    doc = db.collection("users").document(uid).get()
                    if doc.exists:
                        docs.append(doc)
                except Exception:
                    pass
        
        for doc in docs:
            data = doc.to_dict()
            display = data.get("display_name") or data.get("name") or data.get("email", "Unknown User")
            # Don't use placeholder emails as display names
            if isinstance(display, str) and display.endswith("@placeholder.com"):
                display = f"User {doc.id[-4:]}"
            result[doc.id] = {
                "display_name": display,
                "shop_name": data.get("shop_name") or display,
            }
        
        # --- Layer 2: Sellers collection (storeName) ---
        try:
            seller_docs = db.collection("sellers").where("userId", "in", batch
            ).select(["userId", "storeName", "status"]).get()
            for sdoc in seller_docs:
                sdata = sdoc.to_dict()
                uid = sdata.get("userId")
                store_name = sdata.get("storeName")
                if uid and store_name:
                    if uid in result:
                        result[uid]["shop_name"] = store_name
                    else:
                        result[uid] = {"display_name": store_name, "shop_name": store_name}
        except Exception as e:
            logger.warning(f"[IDENTITY] Sellers collection lookup failed: {e}")
        
        # --- Layer 3: Shops collection (authoritative shop_name) ---
        try:
            shop_docs = db.collection("shops").where("__name__", "in",
                [db.collection("shops").document(uid) for uid in batch]
            ).select(["shop_name", "owner_id"]).get()
            for shop_doc in shop_docs:
                shop_data = shop_doc.to_dict()
                owner_id = shop_data.get("owner_id") or shop_doc.id
                shop_name = shop_data.get("shop_name")
                if shop_name:
                    if owner_id in result:
                        result[owner_id]["shop_name"] = shop_name
                    else:
                        result[owner_id] = {"display_name": shop_name, "shop_name": shop_name}
        except Exception as e:
            logger.warning(f"[IDENTITY] Shops collection lookup failed: {e}")
    
    # Fill missing UIDs with safe fallback
    for uid in unique_ids:
        if uid not in result:
            result[uid] = {
                "display_name": f"User {uid[-4:]}",
                "shop_name": f"Shop {uid[-4:]}",
            }
    
    logger.info(f"[IDENTITY] Resolved {len(result)}/{len(unique_ids)} user names")
    return result

async def get_paginated_data(query, limit: int, offset: int, resource_name: str):
    """Helper to paginate Firestore queries and return a standardized response."""
    try:
        # Get total count (optimized count aggregation if possible)
        try:
            total = query.count().get()[0][0].value
        except Exception:
            # Fallback if count() is not supported
            total = len(query.get())
            
        # Get paginated docs
        docs = query.offset(offset).limit(limit).get()
        
        items = []
        for doc in docs:
            data = doc.to_dict()
            data["id"] = doc.id
            # Convert timestamps to ISO strings for JSON compatibility
            for field, value in data.items():
                if hasattr(value, "isoformat"):
                    data[field] = value.isoformat()
            items.append(data)
            
        return {
            "total": total,
            "limit": limit,
            "offset": offset,
            resource_name: items
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pagination error: {str(e)}")

# MODULE 1 - COMMAND CENTER DASHBOARD
@router.get("/dashboard")
async def get_admin_dashboard(user: dict = Depends(require_admin)):
    """Fetch cached stats for admin dashboard."""
    return await AdminStatsService.get_dashboard_stats()

@router.get("/dashboard/stats")
async def get_dashboard_stats_legacy(user: dict = Depends(require_admin)):
    """Legacy endpoint for backward compatibility."""
    return await AdminStatsService.get_dashboard_stats()

# MODULE 2 - USER MANAGEMENT
@router.get("/users")
async def list_users(
    limit: int = Query(20, ge=1, le=100), 
    offset: int = Query(0, ge=0), 
    role: str = None, 
    search: str = None,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "support_admin"]))
):
    query = db.collection("users")
    if role:
        query = query.where("role", "==", role)
    
    # Text search in Firestore is complex; for MVP we'll keep it simple or remove from query layer
    # If search is provided, we might still have to fetch more and filter manually, 
    # but the task is to implement pagination for large datasets.
    # For now, let's prioritize the server-side pagination of the base query.
    result = await get_paginated_data(query, limit, offset, "users")
    
    # Post-process for identity healing (placeholder cleanup)
    users = result.get("users", [])
    for u in users:
        display = u.get("display_name") or u.get("name") or u.get("email", "Unknown User")
        if isinstance(display, str) and display.endswith("@placeholder.com"):
            u["display_name"] = f"User {u['id'][-4:]}"
            u["name"] = u["display_name"]
        else:
            u["display_name"] = display
            
    return result

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
    limit: int = Query(20, ge=1, le=100), 
    offset: int = Query(0, ge=0), 
    status: str = "pending",
    user: dict = Depends(require_role(["super_admin", "operations_admin", "support_admin"]))
):
    # Sellers collection uses uppercase status (PENDING, APPROVED, REJECTED)
    query_status = status.upper()
    query = db.collection("sellers").where("status", "==", query_status)
    
    result = await get_paginated_data(query, limit, offset, "applications")
    
    # Resolve user info for the list view if needed
    apps = result.get("applications", [])
    if apps:
        uids = [a.get("userId") for a in apps if a.get("userId")]
        identities = batch_resolve_user_names(uids)
        for a in apps:
            uid = a.get("userId")
            if uid in identities:
                a["applicant_name"] = identities[uid]["display_name"]
                a["shop_name"] = identities[uid]["shop_name"]
    
    logger.info(f"[SELLER MGMT] Fetched {len(apps)} {query_status} applications from 'sellers' collection.")
    return result

@router.get("/sellers/applications/{app_id}")
async def get_seller_application_detail(
    app_id: str,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "support_admin"]))
):
    """Get full detail of a seller application for the Deep Dive modal."""
    try:
        # Check 'sellers' collection
        doc = db.collection("sellers").document(app_id).get()
        if not doc.exists:
            # Try searching by userId if app_id is actually a userId
            docs = db.collection("sellers").where("userId", "==", app_id).limit(1).get()
            if len(docs) > 0:
                doc = docs[0]
            else:
                raise HTTPException(status_code=404, detail="Application/Seller not found")
        
        data = doc.to_dict()
        data["id"] = doc.id
        
        # Convert timestamps
        for field, value in data.items():
            if hasattr(value, "isoformat"):
                data[field] = value.isoformat()
        
        # Map fields for frontend compatibility (Deep Dive modal)
        # Frontend expects: id_photo, selfie, business_permit
        data["id_photo"] = data.get("identity_image_url")
        data["selfie"] = data.get("selfie_image_url")
        # Note: Business permit might be in seller_documents collection in some flows, 
        # but the schema only had identity and selfie in the main doc.
        # We can also fetch from seller_documents if needed.
        
        # Resolve applicant user info
        uid = data.get("userId") or data.get("user_id")
        if uid:
            try:
                user_doc = db.collection("users").document(uid).get()
                if user_doc.exists:
                    u = user_doc.to_dict()
                    data["applicant_name"] = u.get("display_name") or u.get("email", "Unknown")
                    data["applicant_email"] = u.get("email", "N/A")
                    data["applicant_phone"] = u.get("phone") or u.get("display_phone") or "N/A"
                    data["user_id"] = uid
                else:
                    data["applicant_name"] = "Deleted User"
            except Exception:
                data["applicant_name"] = "Unknown"
        
        logger.info(f"[SELLER MGMT] Fetched detail for application: {app_id}")
        return data
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching seller detail: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/sellers/applications/{app_id}/approve")
async def approve_seller_application(
    app_id: str,
    user: dict = Depends(require_role(["super_admin", "operations_admin"]))
):
    try:
        # Use the centralized service to ensure shop creation and notifications
        success, message = seller_svc_approve(app_id)
        if not success:
            raise HTTPException(status_code=400, detail=message)
            
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "approve_seller",
            "target_id": app_id,
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True, "message": message}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/sellers/applications/{app_id}/reject")
async def reject_seller_application(
    app_id: str,
    reason: str,
    user: dict = Depends(require_role(["super_admin", "operations_admin"]))
):
    try:
        # Use the centralized service
        success, message = seller_svc_reject(app_id, reason=reason)
        if not success:
            raise HTTPException(status_code=400, detail=message)
            
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "reject_seller",
            "target_id": app_id,
            "details": f"Reason: {reason}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        return {"success": True, "message": message}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 4 - PRODUCT MODERATION
@router.get("/products")
async def list_products(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    status: str = None,
    seller_id: str = None,
    category: str = None,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "moderator"]))
):
    query = db.collection("products")
    if status:
        query = query.where("status", "==", status)
    if seller_id:
        query = query.where("seller_id", "==", seller_id)
    if category:
        query = query.where("category", "==", category)
    
    result = await get_paginated_data(query, limit, offset, "products")
    
    # Batch resolve seller names to avoid N+1
    products = result.get("products", [])
    seller_ids = [p.get("seller_id") or p.get("sellerId") for p in products]
    name_map = batch_resolve_user_names(seller_ids)
    
    for product in products:
        sid = product.get("seller_id") or product.get("sellerId") or ""
        resolved = name_map.get(sid, {})
        product["seller_name"] = resolved.get("shop_name", "Unknown Seller")
        logger.info(f"[MODERATION] Resolved Shop Name: {product['seller_name']} for Product: {product.get('id')}")
    
    return result

@router.put("/products/{product_id}/status")
async def update_product_status(
    product_id: str,
    status: str, # "active", "hidden", "archived"
    reason: str = None,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "moderator"]))
):
    try:
        if status not in ["active", "hidden", "archived", "rejected", "suspended"]:
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
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    status: str = None, 
    user_id: str = None,
    seller_id: str = None,
    user: dict = Depends(require_role(["super_admin", "operations_admin", "support_admin", "finance_admin"]))
):
    query = db.collection("orders")
    if status:
        query = query.where("status", "==", status)
    if user_id:
        query = query.where("user_id", "==", user_id)
    if seller_id:
        query = query.where("seller_id", "==", seller_id)
        
    # Order by created_at descending (requires index)
    query = query.order_by("created_at", direction="DESCENDING")
        
    result = await get_paginated_data(query, limit, offset, "orders")
    
    # Batch resolve buyer + seller names (The Trinity Fetch)
    orders = result.get("orders", [])
    all_user_ids = []
    for order in orders:
        uid = order.get("user_id") or order.get("userId") or ""
        sid = order.get("seller_id") or order.get("sellerId") or ""
        if uid:
            all_user_ids.append(uid)
        if sid:
            all_user_ids.append(sid)
    
    name_map = batch_resolve_user_names(all_user_ids)
    
    for order in orders:
        uid = order.get("user_id") or order.get("userId") or ""
        sid = order.get("seller_id") or order.get("sellerId") or ""
        
        buyer_info = name_map.get(uid, {})
        seller_info = name_map.get(sid, {})
        order["buyer_name"] = buyer_info.get("display_name", "Deleted User")
        order["seller_name"] = seller_info.get("shop_name", "Deleted Seller")
        
        # Resolve product thumbnail from first item
        items = order.get("items", [])
        if items and isinstance(items, list) and len(items) > 0:
            first_item = items[0] if isinstance(items[0], dict) else {}
            product_id = first_item.get("product_id") or first_item.get("productId")
            if product_id:
                try:
                    prod_doc = db.collection("products").document(product_id).get()
                    if prod_doc.exists:
                        prod_data = prod_doc.to_dict()
                        images = prod_data.get("images") or prod_data.get("imageUrls") or []
                        order["thumbnail_url"] = images[0] if images else None
                    else:
                        order["thumbnail_url"] = None
                except Exception:
                    order["thumbnail_url"] = None
            else:
                order["thumbnail_url"] = None
        else:
            order["thumbnail_url"] = None
        
        logger.info(f"[ORDER CTRL] Resolved Image & Identities for Order: {order.get('id')}")
    
    return result

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
        from datetime import datetime, timedelta
        
        orders_ref = db.collection("orders").select(["status", "total_price", "created_at"]).stream()
        
        total_gmv = 0.0
        platform_revenue = 0.0
        seller_payouts = 0.0
        refunds = 0.0
        
        now = datetime.now(UTC).replace(tzinfo=None)
        weekly_revenue = [0.0, 0.0, 0.0, 0.0]
        
        for doc in orders_ref:
            data = doc.to_dict()
            status = data.get("status")
            price = float(data.get("total_price", 0.0))
            
            if status not in ["cancelled", "refunded"]:
                total_gmv += price
                platform_revenue += price * 0.05
                seller_payouts += price * 0.95
                
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

            elif status == "refunded":
                refunds += price
                
        return {
            "total_gmv": total_gmv,
            "net_revenue": platform_revenue,
            "total_payouts": seller_payouts,
            "pending_refunds": refunds,
            "weekly_revenue": weekly_revenue
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 7 - MARKETING CENTER
@router.get("/marketing/vouchers")
async def list_all_vouchers(user: dict = Depends(require_admin)):
    """List all platform-wide and seller-specific vouchers with expiry status."""
    try:
        now = datetime.now(UTC).replace(tzinfo=None)
        
        all_vouchers = []
        
        # 1. Fetch Platform Vouchers
        platform_docs = db.collection("vouchers").get()
        for doc in platform_docs:
            data = doc.to_dict()
            data["id"] = doc.id
            data["type"] = "platform"
            data["seller_name"] = "Swipify"
            # Support both camelCase (old) and snake_case (new)
            data["code"] = data.get("code") or doc.id
            data["discount_type"] = data.get("discount_type") or data.get("discountType") or "percentage"
            data["value"] = data.get("value") or data.get("discount_value") or data.get("discountValue") or 0.0
            data["min_spend"] = data.get("min_spend") or data.get("min_order_amount") or data.get("minimumSpend") or 0.0
            data["usage_count"] = data.get("usage_count") or data.get("used_count") or 0
            data["usage_limit"] = data.get("max_usage") or data.get("usage_limit") or data.get("max_uses") or 999999
            data["max_usage"] = data["usage_limit"] # Ensure consistency with model
            data["start_date"] = data.get("start_date") or data.get("created_at")
            data["end_date"] = data.get("end_date") or data.get("expiryDate")
            all_vouchers.append(data)
            
        # 2. Fetch Seller Vouchers
        seller_docs = db.collection("seller_vouchers").get()
        seller_vouchers_list = []
        for doc in seller_docs:
            data = doc.to_dict()
            data["id"] = doc.id
            data["type"] = "seller"
            # Map seller voucher fields to match unified schema
            data["usage_count"] = data.get("used_count") or data.get("usage_count") or 0
            data["usage_limit"] = data.get("usage_limit") or 999999
            data["min_spend"] = data.get("min_order_amount") or data.get("min_spend") or 0.0
            data["value"] = data.get("discount_value") or data.get("value") or 0.0
            seller_vouchers_list.append(data)
            
        # 3. Resolve Seller Names for Seller Vouchers
        seller_ids = [v.get("seller_id") for v in seller_vouchers_list if v.get("seller_id")]
        name_map = batch_resolve_user_names(seller_ids)
        for v in seller_vouchers_list:
            sid = v.get("seller_id")
            v["seller_name"] = name_map.get(sid, {}).get("shop_name", "Unknown Seller")
            all_vouchers.append(v)
            
        # 4. Final Processing (Expiry & Timestamps)
        for data in all_vouchers:
            # Compute expiry status
            end_date = data.get("end_date")
            if end_date:
                if hasattr(end_date, "to_datetime"):
                    end_dt = end_date.to_datetime().replace(tzinfo=None)
                elif isinstance(end_date, str):
                    try:
                        # Handle potential timezone Z or offset
                        clean_date = end_date.split('.')[0] if '.' in end_date else end_date
                        if clean_date.endswith('Z'):
                            clean_date = clean_date[:-1]
                        end_dt = datetime.fromisoformat(clean_date).replace(tzinfo=None)
                    except ValueError:
                        end_dt = None
                else:
                    end_dt = None
                
                if end_dt:
                    data["is_expired"] = now > end_dt
                else:
                    data["is_expired"] = False
            else:
                data["is_expired"] = False
            
            # Convert timestamps to ISO strings
            for field in ["start_date", "end_date", "created_at"]:
                if field in data and hasattr(data[field], "isoformat"):
                    data[field] = data[field].isoformat()
        
        logger.info(f"[MARKETING] Unified vouchers fetched. Total: {len(all_vouchers)}")
        return all_vouchers
    except Exception as e:
        logger.error(f"[MARKETING] Error loading unified vouchers: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/marketing/vouchers")
async def create_platform_voucher(
    voucher_data: PlatformVoucherCreateRequest,
    user: dict = Depends(require_role(["super_admin", "marketing_admin"]))
):
    """Create a new platform-wide voucher."""
    try:
        # Check if code already exists
        existing = db.collection("vouchers").where("code", "==", voucher_data.code.upper()).get()
        if existing:
            raise HTTPException(status_code=400, detail="Voucher code already exists")
            
        doc_data = voucher_data.dict()
        doc_data["code"] = doc_data["code"].upper()
        doc_data["usage_count"] = 0
        doc_data["created_at"] = SERVER_TIMESTAMP
        
        # Also add camelCase fields for backward compatibility with existing platform logic if needed
        doc_data["discountType"] = doc_data["discount_type"]
        doc_data["discountValue"] = doc_data["value"]
        doc_data["minimumSpend"] = doc_data["min_spend"]
        doc_data["expiryDate"] = doc_data["end_date"].isoformat() if hasattr(doc_data["end_date"], "isoformat") else doc_data["end_date"]
        doc_data["title"] = f"{doc_data['code']} Promo"
        
        doc_ref = db.collection("vouchers").add(doc_data)
        
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

@router.put("/marketing/vouchers/{voucher_id}")
async def update_platform_voucher(
    voucher_id: str,
    voucher_data: PlatformVoucherUpdateRequest,
    user: dict = Depends(require_role(["super_admin", "marketing_admin"]))
):
    """Update an existing platform voucher (partial update)."""
    try:
        voucher_ref = db.collection("vouchers").document(voucher_id)
        if not voucher_ref.get().exists:
            raise HTTPException(status_code=404, detail="Voucher not found")
        
        update_data = voucher_data.dict(exclude_none=True)
        if not update_data:
            raise HTTPException(status_code=400, detail="No fields to update")
        
        # Normalize code to uppercase if provided
        if "code" in update_data:
            update_data["code"] = update_data["code"].upper()
        
        # Also sync camelCase fields for backward compatibility
        if "discount_type" in update_data:
            update_data["discountType"] = update_data["discount_type"]
        if "value" in update_data:
            update_data["discountValue"] = update_data["value"]
        if "min_spend" in update_data:
            update_data["minimumSpend"] = update_data["min_spend"]
        if "end_date" in update_data:
            ed = update_data["end_date"]
            update_data["expiryDate"] = ed.isoformat() if hasattr(ed, "isoformat") else ed
        
        update_data["updated_at"] = SERVER_TIMESTAMP
        voucher_ref.update(update_data)
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "update_platform_voucher",
            "target_id": voucher_id,
            "details": f"Updated fields: {list(update_data.keys())}",
            "timestamp": SERVER_TIMESTAMP
        })
        
        logger.info(f"[MARKETING] Voucher {voucher_id} updated by {user['uid']}")
        return {"success": True}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[MARKETING] Error updating voucher {voucher_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/marketing/vouchers/{voucher_id}")
async def delete_platform_voucher(
    voucher_id: str,
    user: dict = Depends(require_role(["super_admin", "marketing_admin"]))
):
    """Delete a platform-wide voucher."""
    try:
        # Check both collections just in case, but usually admin deletes platform ones
        voucher_ref = db.collection("vouchers").document(voucher_id)
        if not voucher_ref.get().exists:
            # Fallback to seller_vouchers if admin wants to delete a seller voucher
            voucher_ref = db.collection("seller_vouchers").document(voucher_id)
            if not voucher_ref.get().exists:
                raise HTTPException(status_code=404, detail="Voucher not found")
            
        voucher_ref.delete()
        
        # Log action
        db.collection("audit_logs").add({
            "admin_id": user["uid"],
            "action": "delete_voucher",
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
        platform_vouchers = db.collection("vouchers").get()
        seller_vouchers = db.collection("seller_vouchers").get()
        
        total_vouchers = len(platform_vouchers) + len(seller_vouchers)
        
        # Real aggregated redemptions
        platform_usage = sum(doc.to_dict().get("usage_count") or doc.to_dict().get("used_count") or 0 for doc in platform_vouchers)
        seller_usage = sum(doc.to_dict().get("used_count") or doc.to_dict().get("usage_count") or 0 for doc in seller_vouchers)
        
        # If platform usage is 0 in vouchers, try counting claimedVouchers where used=True
        if platform_usage == 0:
            claimed_docs = db.collection("claimedVouchers").where("used", "==", True).get()
            platform_usage = len(claimed_docs)
        
        # Active campaigns count (vouchers that haven't expired)
        now = datetime.now(UTC).replace(tzinfo=None)
        active_count = 0
        
        for doc in platform_vouchers:
            v = doc.to_dict()
            end = v.get("end_date")
            if end:
                if hasattr(end, "to_datetime"):
                    end_dt = end.to_datetime().replace(tzinfo=None)
                elif isinstance(end, str):
                    try:
                        end_dt = datetime.fromisoformat(end.split('Z')[0]).replace(tzinfo=None)
                    except ValueError:
                        end_dt = None
                else:
                    end_dt = None
                
                if end_dt and end_dt > now:
                    active_count += 1
                    
        for doc in seller_vouchers:
            v = doc.to_dict()
            end = v.get("end_date")
            if end:
                try:
                    end_dt = datetime.fromisoformat(end.split('Z')[0]).replace(tzinfo=None)
                    if end_dt > now:
                        active_count += 1
                except Exception:
                    pass

        return {
            "total_vouchers": total_vouchers,
            "total_redemptions": platform_usage + seller_usage,
            "active_campaigns": active_count
        }
    except Exception as e:
        logger.error(f"[MARKETING STATS] Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# MODULE 8 - SUPPORT & DISPUTES
@router.get("/support/tickets")
async def list_support_tickets(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    status: str = None,
    priority: str = None,
    user: dict = Depends(require_role(["super_admin", "support_admin"]))
):
    query = db.collection("support_tickets")
    if status:
        query = query.where("status", "==", status)
    if priority:
        query = query.where("priority", "==", priority)
    
    query = query.order_by("created_at", direction="DESCENDING")
    result = await get_paginated_data(query, limit, offset, "tickets")
    
    # Resolve user info for the list view
    tickets = result.get("tickets", [])
    if tickets:
        uids = []
        for t in tickets:
            if t.get("user_id"): uids.append(t["user_id"])
            if t.get("assigned_to"): uids.append(t["assigned_to"])
        
        identities = batch_resolve_user_names(uids)
        for t in tickets:
            uid = t.get("user_id")
            aid = t.get("assigned_to")
            if uid in identities:
                t["user_name"] = identities[uid]["display_name"]
            if aid in identities:
                t["assignee_name"] = identities[aid]["display_name"]
                
    return result

@router.get("/support/disputes")
async def list_disputes(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    status: str = None,
    user: dict = Depends(require_role(["super_admin", "support_admin", "finance_admin"]))
):
    query = db.collection("disputes")
    if status:
        query = query.where("status", "==", status)
        
    query = query.order_by("created_at", direction="DESCENDING")
    result = await get_paginated_data(query, limit, offset, "disputes")
    
    # Resolve user info for the list view
    disputes = result.get("disputes", [])
    if disputes:
        uids = []
        for d in disputes:
            if d.get("buyer_id"): uids.append(d["buyer_id"])
            if d.get("seller_id"): uids.append(d["seller_id"])
        
        identities = batch_resolve_user_names(uids)
        for d in disputes:
            bid = d.get("buyer_id")
            sid = d.get("seller_id")
            if bid in identities:
                d["buyer_name"] = identities[bid]["display_name"]
            if sid in identities:
                d["seller_name"] = identities[sid]["shop_name"]
                
    return result

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
