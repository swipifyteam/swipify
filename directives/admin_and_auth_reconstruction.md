# DIRECTIVE: Admin and Auth Reconstruction
Version: 1.0.0

## Objective
Establish a fully functional administrative access layer and a premium authentication experience (Signup/Login) for Swipify.

## Success Criteria
1. `SignupScreen` logic matches `LoginScreen` and is fully validated.
2. Administrative users (super_admin) can access the Command Center.
3. API communication uses structured headers and error handling.

## Inputs
- `AuthProvider`: State management for user authentication.
- `AppUser`: Domain model with `isAdmin` privileges.
- `AdminService`: Service layer for admin-only API calls.

## Outputs
- `SignupScreen`: UI component for account creation.
- `AdminDashboardScreen`: Functional dashboard for system management.

## Environment Requirements
- Firebase project with Firestore and Auth enabled.
- Correct `active_project` in Firebase environment (currently `smartbez`).

## Execution Flow
1. **User Promotion**: Set user role to `super_admin` in Firestore `users` collection.
2. **Auth Verification**: Implement and test `SignupScreen`.
3. **Route Protection**: Ensure `AdminDashboardScreen` is only accessible via `isAdmin` check in UI and backend.

## Edge Cases
- Non-admin users attempting to access admin routes (handled by `isAdmin` check).
- Network failures during signup (handled by `AuthProvider` error mapping).
- Missing Firestore user document for an authenticated Firebase user.

## Evolution History
- 2026-04-22: Initial version. Promoted `mykhel@gmail.com` to `super_admin`. Recreated `SignupScreen`.
