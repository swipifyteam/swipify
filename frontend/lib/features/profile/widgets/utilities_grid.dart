import 'package:flutter/material.dart';
import 'package:swipify/features/profile/screens/settings_screen.dart';
import 'package:swipify/features/profile/screens/orders_screen.dart';
import 'package:swipify/features/profile/screens/reviews_screen.dart';
import 'package:swipify/features/profile/screens/help_screen.dart';
import 'package:swipify/features/profile/screens/address_list_screen.dart';

import 'package:provider/provider.dart';
import 'package:swipify/features/profile/service/user_provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/seller/domain/entities/seller_entity.dart';
import 'package:swipify/features/seller/presentation/pages/seller_dashboard_page.dart';
import 'package:swipify/features/seller/presentation/pages/seller_onboarding_page.dart';
import 'package:swipify/features/seller/presentation/pages/seller_status_page.dart';
import 'package:swipify/features/seller/presentation/pages/seller_reapply_page.dart';
import 'package:swipify/features/admin/pages/admin_sellers_page.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';

class UtilitiesGrid extends StatelessWidget {
  const UtilitiesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Consumer<SellerProvider>(
          builder: (context, seller, _) {
            final isSeller = seller.status == SellerStatus.approved;
            return _buildListTile(
              context,
              Icons.storefront_outlined,
              isSeller ? 'My Shop' : 'Start Selling',
              '',
              onTap: () {
                Widget? dest;
                switch (seller.status) {
                  case SellerStatus.notApplied:
                    dest = const SellerOnboardingPage();
                    break;
                  case SellerStatus.pending:
                    dest = const SellerStatusPage();
                    break;
                  case SellerStatus.approved:
                    dest = const SellerDashboardPage();
                    break;
                  case SellerStatus.rejected:
                    dest = const SellerReapplyPage();
                    break;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => dest!),
                );
              },
            );
          },
        ),
        _buildListTile(context, Icons.star_border, 'My Reviews', '', onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen()))),
        _buildListTile(context, Icons.receipt_long_outlined, 'My Orders', '', onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),
        _buildListTile(context, Icons.location_on_outlined, 'My Addresses', '', onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressListScreen()))),
        _buildListTile(context, Icons.headset_mic_outlined, 'Help Centre', '', onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))),
        _buildListTile(context, Icons.settings_outlined, 'Account Settings', '', onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),

        // Admin Portal
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final role = context.watch<UserProvider>().profile?.role ?? "buyer";
            if (role == 'admin') {
              return Column(
                children: [
                  const Divider(height: 32, color: Colors.transparent),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Admin Controls', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  _buildListTile(
                    context,
                    Icons.admin_panel_settings_outlined,
                    'Seller Applications',
                    '',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminSellersPage()),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, String trailingText, {required VoidCallback onTap}) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: Colors.black87, size: 24),
            title: Text(title, style: const TextStyle(fontSize: 14)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingText.isNotEmpty)
                  Text(trailingText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
            onTap: onTap,
          ),
          const Divider(height: 1, indent: 56),
        ],
      ),
    );
  }
}
