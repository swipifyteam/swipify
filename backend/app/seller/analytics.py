from fastapi import APIRouter, Depends, HTTPException, Query
from app.utils.auth_utils import get_current_user_id
from app.seller.schemas import AnalyticsResponse, DailySalesData
from firebase_client import db
from datetime import datetime, timedelta, timezone
from typing import List, Optional

router = APIRouter()

@router.get("/daily-sales", response_model=AnalyticsResponse)
async def get_daily_sales_analytics(
    seller_id: str, 
    days: int = Query(7, ge=1, le=90),
    current_user_id: str = Depends(get_current_user_id)
):
    """
    Fetch daily sales analytics for a specific seller.
    Groups delivered/completed orders by date.
    """
    # Security: Ensure the requester owns the seller account
    if seller_id != current_user_id:
        raise HTTPException(status_code=403, detail="Unauthorized access to analytics")
    
    # Calculate date range
    now = datetime.now(timezone.utc)
    start_date = now - timedelta(days=days)
    # For string-based ISO comparison in Firestore, we use the date part
    start_date_str = start_date.isoformat()
    
    try:
        # Fetch orders for this seller created within the range
        # Optimized: Only fetch what's needed for the chart
        docs = db.collection("orders")\
            .where("seller_id", "==", seller_id)\
            .where("created_at", ">=", start_date_str)\
            .get()
        
        today_str = now.strftime("%Y-%m-%d")
        today_revenue = 0.0
        today_order_count = 0
        total_revenue = 0.0
        total_order_count = 0
        
        # Initialize daily map to ensure all dates in range exist (even with 0 sales)
        daily_map = {}
        for i in range(days + 1):
            d_key = (now - timedelta(days=i)).strftime("%Y-%m-%d")
            daily_map[d_key] = {"revenue": 0.0, "count": 0}

        for doc in docs:
            order = doc.to_dict()
            status = order.get("status")
            
            # Analytics only counts successful transactions for revenue
            if status not in ["delivered", "completed"]:
                continue
                
            created_at_str = order.get("created_at")
            if not created_at_str:
                continue
                
            try:
                # Handle ISO string (works with 'Z' or '+00:00')
                dt = datetime.fromisoformat(created_at_str.replace('Z', '+00:00'))
                date_str = dt.strftime("%Y-%m-%d")
                
                price = float(order.get("total_price", 0.0))
                
                # Global totals (within the requested range)
                total_revenue += price
                total_order_count += 1
                
                # Today's stats
                if date_str == today_str:
                    today_revenue += price
                    today_order_count += 1
                    
                # Chart stats
                if date_str in daily_map:
                    daily_map[date_str]["revenue"] += price
                    daily_map[date_str]["count"] += 1
                    
            except (ValueError, TypeError) as e:
                print(f"[ANALYTICS ERROR] Parsing date for order {doc.id}: {e}")
                continue
                
        # Convert map to sorted list for the chart (Ascending date)
        daily_stats = []
        for d in sorted(daily_map.keys()):
            daily_stats.append(DailySalesData(
                date=d,
                revenue=round(daily_map[d]["revenue"], 2),
                order_count=daily_map[d]["count"]
            ))
            
        return AnalyticsResponse(
            today_revenue=round(today_revenue, 2),
            today_order_count=today_order_count,
            total_revenue=round(total_revenue, 2),
            total_order_count=total_order_count,
            daily_stats=daily_stats
        )
        
    except Exception as e:
        print(f"[ANALYTICS CRITICAL] {e}")
        raise HTTPException(status_code=500, detail=str(e))
