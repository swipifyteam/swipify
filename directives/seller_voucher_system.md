# Directive: Seller Voucher System

## Objective
Implement a fully dynamic Seller Voucher System where sellers can create and manage vouchers, and buyers can apply them during checkout.

## Inputs
- `user_id`
- `seller_id`
- `voucher_code`
- `cart_total`
- `discount_type` ("percentage" or "fixed")
- `discount_value`
- `min_order_amount`
- `usage_limit`
- `start_date`
- `end_date`

## Outputs
- `discount` (calculated value)
- `final_total`
- `voucher_id` (created)
- `is_valid` (bool)

## Dependencies
- Backend: FastAPI, Firestore
- Frontend: Flutter, Firebase Auth (for user_id), API Service

## Execution Flow
1. **Backend Implementation**
    - Create `Voucher` model.
    - Implement `POST /seller/vouchers` (Create).
    - Implement `GET /seller/vouchers/{seller_id}` (List).
    - Implement `POST /voucher/apply` (Validate & Calculate).
    - Implement logic to update `used_count` on order completion.
2. **Frontend Implementation**
    - Create `SellerVoucherScreen` for voucher creation and viewing.
    - Update `CheckoutScreen` to include voucher application logic.
    - Integrate with `ApiService`.
3. **Integration & Testing**
    - Verify voucher creation.
    - Verify validation rules (expiry, seller match, usage limit).
    - Verify correct discount calculation per seller.

## Failure Handling
- **Invalid Voucher**: Return specific error message (Expired, Limit reached, etc.)
- **Wrong Seller**: Reject application if seller_id doesn't match.
- **Backend Error**: Log error and return 500.

## Edge Cases
- Expiration: Check if current date is within `start_date` and `end_date`.
- Usage Limit: Prevent incrementing `used_count` if limit is reached.
- Negative Total: Ensure `final_total` is never negative.
- Multi-seller: Apply discount only to the relevant seller's subtotal.
