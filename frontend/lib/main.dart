// lib/main.dart
// Main entry point for the Swipify app.
// 🚨 FULL RECONSTRUCTION WITH MODULAR ARCHITECTURE (PART 11) 🚨

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Foundation
import 'firebase_options.dart';
import 'package:swipify/core/theme.dart';

// Features - Auth
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/auth/screen/login_screen.dart';
import 'package:swipify/features/auth/screen/signup_screen.dart';

// Features - Navigation
import 'package:swipify/features/splash/screen/splash_screen.dart';
import 'package:swipify/features/navigation/main_nav_screen.dart';
import 'package:swipify/features/navigation/service/navigation_provider.dart';

// Features - Core Ecommerce
import 'package:swipify/features/cart/service/cart_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/seller/service/seller_products_provider.dart';
import 'package:swipify/features/seller/service/seller_vouchers_provider.dart';
import 'package:swipify/features/profile/service/user_provider.dart';
import 'package:swipify/features/orders/service/order_provider.dart';
import 'package:swipify/features/checkout/service/checkout_provider.dart';
import 'package:swipify/features/profile/service/address_provider.dart';

// Legacy/Auxiliary
import 'package:swipify/features/navigation/service/notification_provider.dart';

// Routes and Additional Screens
import 'package:swipify/features/profile/screens/orders_screen.dart';
import 'package:swipify/features/seller/presentation/pages/seller_dashboard_page.dart';
import 'package:swipify/features/seller/presentation/pages/product_form_page.dart';
import 'package:swipify/features/admin/pages/admin_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Load context
  try {
     await dotenv.load(fileName: ".env");
  } catch (e) {
     debugPrint('[APP] Warning: No .env file found.');
  }

  // 2. Init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 3. Resolve Auth State
  final authProvider = AuthProvider();
  await authProvider.handlePendingRedirect();

  runApp(Swipify(authProvider: authProvider));
}

class Swipify extends StatelessWidget {
  final AuthProvider authProvider;

  const Swipify({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Auth: User Session ───────────────
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
        ),

        // ── Navigation & Control ──────────────
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),

        // ── FEATURE PROVIDERS (RECONSTRUCTED) ──
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SellerProvider()),
        ChangeNotifierProvider(create: (_) => SellerProductsProvider()),
        ChangeNotifierProvider(create: (_) => SellerVouchersProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => CheckoutProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
      ],
      child: MaterialApp(
        title: 'Swipify',
        debugShowCheckedModeBanner: false,
        theme: SwipifyTheme.lightTheme,
        
        // Initial Entry (Auth-Gated Splash)
        home: const SplashScreen(),
        
        // NAMED ROUTES (Modular approach)
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const MainNavScreen(),
          '/orders': (context) => const OrdersScreen(),
          '/seller-dashboard': (context) => const SellerDashboardPage(),
          '/add-product': (context) => const ProductFormPage(),
          '/admin': (context) => const AdminDashboardScreen(),
        },
      ),
    );
  }
}
