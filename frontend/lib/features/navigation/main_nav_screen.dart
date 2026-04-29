// lib/features/navigation/main_nav_screen.dart
// Redesign — floating pill bottom navigation bar.
// Consumes Auth, Cart and Navigation providers for consistent state.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:swipify/screens/home_screen.dart';
import 'package:swipify/features/auth/screen/login_screen.dart';
import 'package:swipify/features/navigation/categories_screen.dart';
import 'package:swipify/features/cart/screen/cart_screen.dart';
import 'package:swipify/features/profile/screen/profile_screen.dart';
import 'package:swipify/features/cart/service/cart_provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/navigation/service/navigation_provider.dart';
import 'package:swipify/features/profile/service/user_provider.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _kAccent  = Color(0xFFE97B4A);
const _kCard    = Color(0xFFFFFFFF);
const _kBorder  = Color(0xFFE5E7EB);
const _kText2   = Color(0xFF6B7280);

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        context.read<UserProvider>().loadProfile(auth.user!.uid);
      }
    });
  }

  final List<Widget> _pages = const [
    HomeScreen(),
    CategoriesScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2 || index == 3) {
      final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
      if (!isLoggedIn) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        return;
      }
    }
    context.read<NavigationProvider>().setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Consumer3<AuthProvider, CartProvider, NavigationProvider>(
        builder: (context, authProvider, cartProvider, navProvider, _) {
          final currentIndex = navProvider.selectedIndex;
          final cartCount   = cartProvider.itemCount;
          final isLoggedIn  = authProvider.isLoggedIn;

          return Scaffold(
            backgroundColor: const Color(0xFFF7F8FA),
            body: IndexedStack(
              index: currentIndex,
              children: _pages,
            ),
            bottomNavigationBar: _SwipifyNavBar(
              currentIndex: currentIndex,
              cartCount: cartCount,
              isLoggedIn: isLoggedIn,
              onTap: _onItemTapped,
            ),
          );
        },
      ),
    );
  }
}

// ─── Floating Navigation Bar ─────────────────────────────────────────
class _SwipifyNavBar extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final bool isLoggedIn;
  final ValueChanged<int> onTap;

  const _SwipifyNavBar({
    required this.currentIndex,
    required this.cartCount,
    required this.isLoggedIn,
    required this.onTap,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_outlined,      activeIcon: Icons.home_rounded,            label: 'Home'),
    _NavItemData(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded,       label: 'Categories'),
    _NavItemData(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded, label: 'Cart'),
    _NavItemData(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,      label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        border: Border(top: BorderSide(color: _kBorder, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = currentIndex == i;
              final label = i == 3 ? (isLoggedIn ? 'Profile' : 'Login') : item.label;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? _kAccent.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with cart badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              active ? item.activeIcon : item.icon,
                              color: active ? _kAccent : _kText2,
                              size: 24,
                            ),
                            if (i == 2 && cartCount > 0)
                              Positioned(
                                top: -4, right: -6,
                                child: Container(
                                  width: 16, height: 16,
                                  decoration: const BoxDecoration(color: _kAccent, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                      cartCount > 9 ? '9+' : '$cartCount',
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? _kAccent : _kText2,
                          ),
                        ),
                        // Active indicator dot
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: active ? 16 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData({required this.icon, required this.activeIcon, required this.label});
}
