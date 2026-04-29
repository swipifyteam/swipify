# Directive: Profile Cleanup

## Objective
Simplify the user profile interface by removing deprecated reward and financial overview sections that are no longer part of the primary user experience.

## Inputs
- `ProfileScreen` in `frontend/lib/features/profile/screen/profile_screen.dart`.
- `WalletSection` in `frontend/lib/features/profile/widgets/wallet_section.dart`.

## Success Criteria
- [x] `WalletSection` (Wallet, Coins, Vouchers bar) is removed from the `ProfileScreen`.
- [x] Corresponding widget file is deleted to maintain a clean codebase.
- [x] No broken imports or dead code remaining in the profile feature.

## Execution Flow
1. Identify the `WalletSection` usage in `ProfileScreen`.
2. Remove the widget call and its associated import.
3. Delete the physical file `frontend/lib/features/profile/widgets/wallet_section.dart`.
4. Verify the layout in `ProfileScreen` remains consistent with proper spacing.

## Evolution History
- 2026-04-29: Removed Wallet/Coins/Vouchers section from Profile Screen.
