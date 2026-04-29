import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/orders/service/order_provider.dart';
import 'package:swipify/features/profile/screens/orders_screen.dart';

class OrderStatusOverview extends StatelessWidget {
  const OrderStatusOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Purchases', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen())),
                  child: Row(
                    children: const [
                      Text('View History', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Consumer<OrderProvider>(
              builder: (context, orderProvider, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatusItem(context, Icons.account_balance_wallet_outlined, 'To Pay', tabIndex: 1, badgeCount: orderProvider.toPayCount),
                    _buildStatusItem(context, Icons.local_shipping_outlined, 'To Ship', tabIndex: 2, badgeCount: orderProvider.toShipCount),
                    _buildStatusItem(context, Icons.inventory_2_outlined, 'To Receive', tabIndex: 3, badgeCount: orderProvider.toReceiveCount),
                    _buildStatusItem(context, Icons.star_outline, 'Completed', tabIndex: 4, badgeCount: orderProvider.completedCount),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, IconData icon, String label, {int tabIndex = 0, int badgeCount = 0}) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrdersScreen(initialTab: tabIndex)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 28, color: Colors.black87),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
