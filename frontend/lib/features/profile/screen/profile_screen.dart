// lib/features/profile/screen/profile_screen.dart
// Profile Screen (Me Screen) - Shopee style.
// Restored to "same as last time" design while keeping modular architecture.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/profile/widgets/profile_header.dart';
import 'package:swipify/features/profile/widgets/order_status_overview.dart';
import 'package:swipify/features/profile/widgets/start_selling_cta.dart';
import 'package:swipify/features/profile/widgets/utilities_grid.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/profile/service/user_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    // 🚨 GUEST MODE HANDLING 🚨
    if (user == null) {
      return Scaffold(
        backgroundColor: SwipifyTheme.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 120,
              ),
              const SizedBox(height: 16),
              const Text(
                "Please login to see your profile",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text("LOGIN / SIGNUP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          final user = auth.user;
          if (user != null) {
            await Future.wait<void>([
              context.read<SellerProvider>().loadSellerStatus(user.uid),
              context.read<UserProvider>().loadProfile(user.uid),
            ]);
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // SHOPEE-LIKE HEADER
            const ProfileHeader(),

            // MAIN CONTENT
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // ORDER STATUS GRID (To Pay, To Ship, etc.)
                  const OrderStatusOverview(),
                  
                  const SizedBox(height: 12),
                  // START SELLING BANNER
                  const StartSellingCTA(),
                  
                  const SizedBox(height: 12),
                  // UTILITIES LIST (Likes, History, Reviews, Help, Settings)
                  const UtilitiesGrid(),

                  const SizedBox(height: 32),
                  // VERSION INFO
                  const Text(
                    "Swipify v1.0.0",
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 24),
                  
                  // LOGOUT BUTTON
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => auth.logout(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("LOG OUT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

