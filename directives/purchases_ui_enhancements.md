# Directive: Purchases UI Enhancements

## Objective
Enhance the "Purchases" screen to display real-time badge counts for each order status tab, improving user visibility of their order progress.

## Inputs
- `OrdersScreen` in `frontend/lib/features/profile/screens/orders_screen.dart`.
- `OrderProvider` in `frontend/lib/features/orders/service/order_provider.dart`.

## Success Criteria
- [x] "All", "To Pay", "To Ship", "To Receive", and "Completed" tabs display a count badge if the count is greater than 0.
- [x] Tab logic correctly filters orders based on status and payment status.
- [x] Counts automatically update when order status changes.

## Execution Flow
1. Update `OrderProvider` getters to accurately reflect the categorization logic used in the UI.
2. Refactor `OrdersScreen` to use a `Consumer<OrderProvider>` for the entire layout.
3. Implement `_buildTab` helper in `OrdersScreen` to render labels with styled badge containers.
4. Replace static `Tab` widgets with dynamic ones using the new helper.

## Evolution History
- 2026-04-29: Added badge counts to Purchases tabs and synchronized provider logic with UI filtering.
