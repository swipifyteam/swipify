# Directive: Seller Dashboard Enhancements

## Objective
Enhance the Seller Dashboard's Overview module to provide more context for recent orders by displaying the order date/time.

## Inputs
- `SellerDashboardPage` in `frontend/lib/features/seller/presentation/pages/seller_dashboard_page.dart`.
- `OrderModel` in `frontend/lib/features/orders/model/order_model.dart`.

## Success Criteria
- [x] Each row in the "Recent Orders" list displays the relative time (e.g., "Just now", "2 hrs ago") below the Order ID.
- [x] Layout remains clean and follows the established design system.

## Execution Flow
1. Identify the `_OrderRow` widget in the `SellerDashboardPage`.
2. Wrap the Order ID text in a `Column` to allow for subtext.
3. Use the existing `_timeAgo` helper function to format the `order.createdAt` timestamp.
4. Apply consistent typography using the design system's secondary text color and smaller font size.

## Evolution History
- 2026-04-29: Added order date/time to Recent Orders row.
