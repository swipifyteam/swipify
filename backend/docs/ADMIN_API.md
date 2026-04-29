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

### 6. Support & Disputes
- **GET** `/admin/support/tickets`
  - Query Params: `limit`, `offset`, `status`, `priority`.
  - Sorted by `created_at` DESC.
- **GET** `/admin/support/disputes`
  - Query Params: `limit`, `offset`, `status`.
  - Sorted by `created_at` DESC.

## Security
Administrative access is controlled via the `role` field in the user's Firestore document. Only users with designated admin roles (e.g., `super_admin`, `operations_admin`, `support_admin`, `finance_admin`, `moderator`) can access these endpoints.
