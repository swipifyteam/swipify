import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/seller/domain/entities/seller_entity.dart';
import 'package:swipify/features/seller/presentation/pages/seller_onboarding_page.dart';
import 'package:swipify/features/seller/presentation/pages/seller_status_page.dart';
import 'package:swipify/features/seller/presentation/pages/seller_dashboard_page.dart';
import 'package:swipify/features/seller/presentation/pages/seller_reapply_page.dart';
import 'package:swipify/core/theme.dart';

class StartSellingCTA extends StatelessWidget {
  const StartSellingCTA({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SellerProvider>(
      builder: (context, sellerProvider, child) {
        // If already approved, CTA might change or disappear, but let's keep it and change to "Seller Dashboard"
        final isApproved = sellerProvider.status == SellerStatus.approved;
        
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                SwipifyTheme.primaryColor,
                const Color(0xFF4A5D6A),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: SwipifyTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(isApproved ? Icons.dashboard : Icons.storefront, color: Colors.white, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isApproved ? 'Seller Dashboard' : 'Become a Seller',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isApproved ? 'Manage your store and products' : 'Turn your products into profit',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Navigate based on current status
                  Widget? dest;
                  switch (sellerProvider.status) {
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: SwipifyTheme.primaryColor,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  isApproved ? 'Open' : 'Join Now', 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
