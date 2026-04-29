// ============================================================
// test/features/profile/sub_screens_test.dart
// Widget tests for the Me page sub-screens (Wallet, Coins,
// Vouchers, Orders, Settings).
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/profile/screens/wallet_screen.dart';
import 'package:swipify/features/profile/screens/coins_screen.dart';
import 'package:swipify/features/profile/screens/vouchers_screen.dart';
import 'package:swipify/features/profile/screens/orders_screen.dart';
import 'package:swipify/features/profile/screens/settings_screen.dart';
import 'package:swipify/core/models/app_user.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import '../../helpers/app_wrapper.dart';
import '../../helpers/mock_auth_provider.dart';
import '../../helpers/mock_order_provider.dart';

void main() {
  setUpAll(disableFontFetching);

  // ─────────── Wallet Screen ───────────
  group('WalletScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const WalletScreen()));
      await tester.pump();
      expect(find.byType(WalletScreen), findsOneWidget);
    });

    testWidgets('shows app bar title "Swipify Wallet"', (tester) async {
      await tester.pumpWidget(testApp(const WalletScreen()));
      await tester.pump();
      // findsWidgets: title appears in both AppBar and balance card
      expect(find.text('Swipify Wallet'), findsWidgets);
    });

    testWidgets('shows total balance with peso sign', (tester) async {
      await tester.pumpWidget(testApp(const WalletScreen()));
      await tester.pump();
      expect(find.text('₱1,250.00'), findsOneWidget);
    });

    testWidgets('shows Top Up action button', (tester) async {
      await tester.pumpWidget(testApp(const WalletScreen()));
      await tester.pump();
      expect(find.text('Top Up'), findsOneWidget);
    });

    testWidgets('shows Recent Transactions section', (tester) async {
      await tester.pumpWidget(testApp(const WalletScreen()));
      await tester.pump();
      // Scroll down to reveal off-screen section
      await tester.dragUntilVisible(
        find.text('Recent Transactions'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Recent Transactions'), findsOneWidget);
    });
  });

  // ─────────── Coins Screen ───────────
  group('CoinsScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const CoinsScreen()));
      await tester.pump();
      expect(find.byType(CoinsScreen), findsOneWidget);
    });

    testWidgets('shows app bar title "Swipify Coins"', (tester) async {
      await tester.pumpWidget(testApp(const CoinsScreen()));
      await tester.pump();
      // findsWidgets: may appear in AppBar and subheaders
      expect(find.text('Swipify Coins'), findsWidgets);
    });

    testWidgets('shows coin balance of 5,000', (tester) async {
      await tester.pumpWidget(testApp(const CoinsScreen()));
      await tester.pump();
      expect(find.text('5,000'), findsOneWidget);
    });

    testWidgets('shows Redeem Coins button', (tester) async {
      await tester.pumpWidget(testApp(const CoinsScreen()));
      await tester.pump();
      await tester.dragUntilVisible(
        find.text('Redeem Coins'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Redeem Coins'), findsOneWidget);
    });
  });

  // ─────────── Vouchers Screen ───────────
  group('VouchersScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const VouchersScreen()));
      await tester.pump();
      expect(find.byType(VouchersScreen), findsOneWidget);
    });

    testWidgets('shows app bar title "My Vouchers"', (tester) async {
      await tester.pumpWidget(testApp(const VouchersScreen()));
      await tester.pump();
      expect(find.text('My Vouchers'), findsWidgets);
    });

    testWidgets('shows "Apply" button for voucher code input', (tester) async {
      await tester.pumpWidget(testApp(const VouchersScreen()));
      await tester.pump();
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('shows voucher code input field', (tester) async {
      await tester.pumpWidget(testApp(const VouchersScreen()));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Enter voucher code'), findsOneWidget);
    });
  });

  // ─────────── Orders Screen ───────────
  group('OrdersScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const OrdersScreen()));
      await tester.pump();
      expect(find.byType(OrdersScreen), findsOneWidget);
    });

    testWidgets('shows "Purchases" app bar title', (tester) async {
      await tester.pumpWidget(testApp(const OrdersScreen()));
      await tester.pump();
      expect(find.text('Purchases'), findsWidgets);
    });

    testWidgets('shows all tab labels', (tester) async {
      await tester.pumpWidget(testApp(const OrdersScreen()));
      await tester.pump();
      expect(find.text('All'), findsOneWidget);
      expect(find.text('To Pay'), findsWidgets);
      expect(find.text('To Ship'), findsWidgets);
    });

    testWidgets('renders order cards on All tab', (tester) async {
      final mockAuth = MockAuthProvider();
      mockAuth.setMockUser(const AppUser(uid: 'test_uid'));
      
      final mockOrders = MockOrderProvider();
      mockOrders.setOrders([
        OrderModel(
          id: 'ord_123',
          userId: 'test_uid',
          sellerId: 'seller_1',
          items: [
            OrderItemModel(
              productId: 'prod_1',
              name: 'Air Max 270',
              quantity: 1,
              price: 2500.0,
            ),
          ],
          totalPrice: 2500.0,
          status: 'pending',
          paymentStatus: 'unpaid',
        ),
      ]);

      await tester.pumpWidget(testApp(const OrdersScreen(), authProvider: mockAuth, orderProvider: mockOrders));
      await tester.pump();
      
      // Card should show first item name
      expect(find.text('Air Max 270'), findsOneWidget);
    });

    testWidgets('deep-links to "To Pay" tab when initialTab is 1', (tester) async {
      final mockAuth = MockAuthProvider();
      mockAuth.setMockUser(const AppUser(uid: 'test_uid'));
      
      final mockOrders = MockOrderProvider();
      mockOrders.setOrders([
        OrderModel(
          id: 'ord_123',
          userId: 'test_uid',
          sellerId: 'seller_1',
          items: [
            OrderItemModel(
              productId: 'prod_1',
              name: 'Air Max 270',
              quantity: 1,
              price: 2500.0,
            ),
          ],
          totalPrice: 2500.0,
          status: 'pending',
          paymentStatus: 'unpaid',
        ),
      ]);

      await tester.pumpWidget(testApp(const OrdersScreen(initialTab: 1), authProvider: mockAuth, orderProvider: mockOrders));
      await tester.pump();
      // Should show the Nike order (To Pay status is pending/unpaid)
      expect(find.text('Air Max 270'), findsOneWidget);
    });
  });

  // ─────────── Settings Screen ───────────
  group('SettingsScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pump();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('shows "Settings" app bar title', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pump();
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('shows Personal Info option', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Personal Info'), findsOneWidget);
    });

    testWidgets('shows Sign Out option', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      // Scroll down to find Sign Out
      await tester.dragUntilVisible(
        find.text('SIGN OUT'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('SIGN OUT'), findsOneWidget);
    });

    testWidgets('Push Notifications toggle starts ON', (tester) async {
      await tester.pumpWidget(testApp(const SettingsScreen()));
      await tester.pump();
      final switchFinder = find.byType(SwitchListTile).first;
      final switchWidget = tester.widget<SwitchListTile>(switchFinder);
      expect(switchWidget.value, isTrue);
    });
  });
}
