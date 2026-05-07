// ============================================================
// test/features/profile/me_screen_test.dart
// Widget tests for the Me / Profile page UI.
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/profile/screen/profile_screen.dart';
import 'package:swipify/features/profile/widgets/order_status_overview.dart';
import 'package:swipify/features/profile/widgets/start_selling_cta.dart';
import 'package:swipify/features/profile/widgets/utilities_grid.dart';
import '../../helpers/app_wrapper.dart';
import '../../helpers/mock_auth_provider.dart';
import '../../helpers/mock_order_provider.dart';
import 'package:swipify/core/models/app_user.dart';

void main() {
  setUpAll(disableFontFetching);

  final mockUser = AppUser(
    uid: 'user123',
    email: 'test@example.com',
    name: 'Swipify User',
  );

  final mockAuth = MockAuthProvider();
  mockAuth.setMockUser(mockUser);

  group('ProfileScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const ProfileScreen(), authProvider: mockAuth));
      await tester.pump();
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('shows profile user name "Swipify User"', (tester) async {
      await tester.pumpWidget(testApp(const ProfileScreen(), authProvider: mockAuth));
      await tester.pump();
      expect(find.text('Swipify User'), findsOneWidget);
    });

    testWidgets('shows Edit Profile button', (tester) async {
      await tester.pumpWidget(testApp(const ProfileScreen(), authProvider: mockAuth));
      await tester.pump();
      expect(find.text('Edit Profile'), findsOneWidget);
    });


    testWidgets('has an OrderStatusOverview', (tester) async {
      await tester.pumpWidget(testApp(const ProfileScreen(), authProvider: mockAuth));
      await tester.pump();
      expect(find.byType(OrderStatusOverview), findsOneWidget);
    });

    testWidgets('has a StartSellingCTA', (tester) async {
      await tester.pumpWidget(testApp(const ProfileScreen(), authProvider: mockAuth));
      await tester.pump();
      expect(find.byType(StartSellingCTA), findsOneWidget);
    });

    testWidgets('has a UtilitiesGrid', (tester) async {
      await tester.pumpWidget(testApp(const ProfileScreen(), authProvider: mockAuth));
      await tester.pump();
      expect(find.byType(UtilitiesGrid), findsOneWidget);
    });
  });


  group('OrderStatusOverview', () {
    final mockOrderProvider = MockOrderProvider();
    // Simulate counts for the test
    mockOrderProvider.setMockCounts(toPay: 2, toShip: 1, toReceive: 0, completed: 5);

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const OrderStatusOverview(), orderProvider: mockOrderProvider));
      await tester.pump();
      expect(find.byType(OrderStatusOverview), findsOneWidget);
    });

    testWidgets('shows "My Purchases" heading', (tester) async {
      await tester.pumpWidget(testApp(const OrderStatusOverview(), orderProvider: mockOrderProvider));
      await tester.pump();
      expect(find.text('My Purchases'), findsOneWidget);
    });

    testWidgets('shows all four order status labels', (tester) async {
      await tester.pumpWidget(testApp(const OrderStatusOverview(), orderProvider: mockOrderProvider));
      await tester.pump();
      expect(find.text('To Pay'), findsOneWidget);
      expect(find.text('To Ship'), findsOneWidget);
      expect(find.text('To Receive'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('shows a badge on "To Pay"', (tester) async {
      await tester.pumpWidget(testApp(const OrderStatusOverview(), orderProvider: mockOrderProvider));
      await tester.pump();
      // Badge count 2 should be visible as a text
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows "View History" button', (tester) async {
      await tester.pumpWidget(testApp(const OrderStatusOverview(), orderProvider: mockOrderProvider));
      await tester.pump();
      expect(find.text('View History'), findsOneWidget);
    });
  });
}
