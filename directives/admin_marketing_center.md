# Directive: Admin Marketing Center (v1)

This directive outlines the implementation of the Marketing Center for the Admin Dashboard in the Swipify platform, adhering to the **System Developer Framework (SDF v1)**.

## 1. Intent
Provide administrators with tools to manage platform-wide marketing initiatives, primarily focusing on global vouchers and promotional campaigns to drive platform growth.

## 2. Specification

### 2.1 Backend (FastAPI)
Add **MODULE 7: MARKETING CENTER** to `app/routes/admin.py`:
- `GET /admin/marketing/vouchers`: List all platform-wide vouchers.
- `POST /admin/marketing/vouchers`: Create a new platform-wide voucher.
- `DELETE /admin/marketing/vouchers/{voucher_id}`: Remove a voucher.
- `GET /admin/marketing/stats`: Get global marketing performance (voucher redemption rates, etc.).

### 2.2 Frontend (Flutter)
- **Service**: Create `AdminMarketingService` in `lib/services/admin_marketing_service.dart`.
- **UI Components**:
    - `AdminMarketingScreen`: Main hub for marketing modules.
    - `VoucherManagementCard`: List and create platform vouchers.
    - `CampaignList`: Manage scheduled promotional banners/events.

### 2.3 Data Model (Firestore)
- Collection: `platform_vouchers`
    - `code`: String (Unique)
    - `discountType`: "percentage" | "fixed"
    - `value`: Number
    - `minSpend`: Number
    - `startDate`: Timestamp
    - `endDate`: Timestamp
    - `usageCount`: Integer
    - `maxUsage`: Integer (Optional)

## 3. Orchestration
1.  **Step 1**: Implement backend endpoints in `backend/app/routes/admin.py`.
2.  **Step 2**: Create `AdminMarketingService` in frontend.
3.  **Step 3**: Develop `AdminMarketingScreen` and integrate into `AdminDashboard`.
4.  **Step 4**: Verify functionality with integration tests.

## 4. Execution
- Use `mcp_firebase-mcp-server` for any initial data seeding if needed.
- Frontend logic must be deterministic and handle loading/error states gracefully.
- All admin actions must be logged to `audit_logs`.
