# Swipify Admin API Documentation

This document describes the administrative API endpoints for Swipify.

## Authentication

All admin endpoints require a valid Firebase ID Token passed in the `Authorization` header as a Bearer token.
Strict verification is enforced; raw UIDs are no longer accepted in production.

`Authorization: Bearer <token>`

## Standard Pagination Response

All list endpoints return a standard paginated response:

```json
{
  "total": 150,
  "limit": 20,
  "offset": 0,
  "resource_name": [...]
}
```

## Endpoints

### 1. Dashboard
- **GET** `/admin/dashboard`
  - Returns cached statistics for the platform.
  - Cache duration: 1 hour.
  - Fields: `total_users`, `total_sellers`, `total_orders`, `gmv`, `platform_revenue`, `pending_seller_approvals`, `refund_requests`, `support_tickets`, `last_updated`.

### 2. User Management
- **GET** `/admin/users`
  - Query Params: `limit` (default 20), `offset` (default 0), `role`.
  - Returns paginated list of users.

### 3. Seller Management
- **GET** `/admin/sellers/applications`
  - Query Params: `limit`, `offset`, `status`.
  - Returns paginated list of seller applications.

### 4. Product Moderation
- **GET** `/admin/products`
  - Query Params: `limit`, `offset`, `status`, `seller_id`, `category`.
  - Returns paginated list of products.

### 5. Order Management
- **GET** `/admin/orders`
  - Query Params: `limit`, `offset`, `status`, `user_id`, `seller_id`.
  - Returns paginated list of orders, sorted by `created_at` DESC.
- **PUT** `/admin/orders/{order_id}/force-cancel`
  - Query Params: `reason`.
  - Force-cancels an order with audit logging.

### 6. Finance Center
- **GET** `/admin/finance/overview`
  - Returns: `total_gmv`, `net_revenue`, `total_payouts`, `pending_refunds`, `weekly_revenue` (array of 4 weekly totals).
  - Auth: `super_admin`, `finance_admin`.

### 7. Marketing Center
- **GET** `/admin/marketing/vouchers`
  - Returns unified list of platform + seller vouchers with expiry status and seller name resolution.
- **POST** `/admin/marketing/vouchers`
  - Body: `{ code, discount_type, value, min_spend, end_date, max_usage? }`.
  - Creates a new platform voucher. Code is uppercased. Maintains camelCase fields for backward compat.
  - Auth: `super_admin`, `marketing_admin`.
- **PUT** `/admin/marketing/vouchers/{voucher_id}`
  - Body: Any subset of `{ code?, discount_type?, value?, min_spend?, end_date?, max_usage? }`.
  - Partial update. Syncs camelCase fields. Audit-logged.
  - Auth: `super_admin`, `marketing_admin`.
- **DELETE** `/admin/marketing/vouchers/{voucher_id}`
  - Deletes from `vouchers` or falls back to `seller_vouchers`. Audit-logged.
  - Auth: `super_admin`, `marketing_admin`.
- **GET** `/admin/marketing/stats`
  - Returns: `total_vouchers`, `total_redemptions`, `active_campaigns`.

### 8. Support & Disputes
- **GET** `/admin/support/tickets`
  - Query Params: `limit`, `offset`, `status`, `priority`.
  - Sorted by `created_at` DESC.
- **PUT** `/admin/support/tickets/{ticket_id}`
  - Body: `{ status?, priority?, assigned_to?, notes? }`.
  - Auth: `super_admin`, `support_admin`.
- **GET** `/admin/support/disputes`
  - Query Params: `limit`, `offset`, `status`.
  - Sorted by `created_at` DESC.
- **PUT** `/admin/support/disputes/{dispute_id}/resolve`
  - Query Params: `resolution` ("refunded" | "rejected"), `notes?`.
  - If refunded, also updates the order status. Audit-logged.
  - Auth: `super_admin`, `support_admin`.

### 9. Platform Settings
- **GET** `/admin/settings`
  - Returns current platform config (commission_rate, payout_threshold, maintenance_mode, etc.).
- **PUT** `/admin/settings`
  - Body: Any subset of config fields. Audit-logged.
  - Auth: `super_admin` only.

## Security
Administrative access is controlled via the `role` field in the user's Firestore document. Only users with designated admin roles (e.g., `super_admin`, `operations_admin`, `support_admin`, `finance_admin`, `moderator`) can access these endpoints.
