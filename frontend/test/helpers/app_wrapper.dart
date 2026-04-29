// ============================================================
// test/helpers/app_wrapper.dart
// Provides a minimal widget wrapper for testing individual
// screens without Firebase initialization or network font fetching.
// ============================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/core/theme.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/profile/service/user_provider.dart';
import 'package:swipify/features/orders/service/order_provider.dart';
import 'mock_auth_provider.dart';
import 'mock_user_provider.dart';
import 'mock_order_provider.dart';
import 'mock_seller_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';

/// Call this once at the beginning of any test group that renders
/// widgets — prevents google_fonts from doing network requests during tests.
void disableFontFetching() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Wraps a [child] widget in a minimal MaterialApp so it can be
/// pumped inside a [WidgetTester] without a real Firebase context.
/// Uses a plain ThemeData (not NotoSans) so fonts don't need fetching.
Widget testApp(Widget child, {
  AuthProvider? authProvider,
  UserProvider? userProvider,
  OrderProvider? orderProvider,
  SellerProvider? sellerProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider ?? MockAuthProvider(),
      ),
      ChangeNotifierProvider<UserProvider>.value(
        value: userProvider ?? MockUserProvider(),
      ),
      ChangeNotifierProvider<OrderProvider>.value(
        value: orderProvider ?? MockOrderProvider(),
      ),
      ChangeNotifierProvider<SellerProvider>.value(
        value: sellerProvider ?? MockSellerProvider(),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(
        primaryColor: SwipifyTheme.primaryColor,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: child,
    ),
  );
}
