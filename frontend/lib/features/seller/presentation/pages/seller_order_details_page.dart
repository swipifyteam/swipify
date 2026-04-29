import 'package:flutter/material.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/orders/model/order_model.dart';

class SellerOrderDetailsPage extends StatelessWidget {
  final OrderModel order;

  const SellerOrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.id.substring(0, 8).toUpperCase()}'),
        backgroundColor: SwipifyTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                   Icon(Icons.info_outline, color: statusColor),
                   const SizedBox(width: 12),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Status: ${order.status.toUpperCase()}', 
                         style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16)),
                       Text('Updated: ${order.updatedAt?.substring(0, 10) ?? 'N/A'}', 
                         style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                     ],
                   )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Shipping Address Snapshot
            const Text('Shipping Address (Snapshot)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            if (order.shippingAddress != null)
              _buildInfoCard(
                context,
                [
                  'Recipient: ${order.shippingAddress!['full_name']}',
                  'Phone: ${order.shippingAddress!['phone']}',
                  'Address: ${order.shippingAddress!['street']}, ${order.shippingAddress!['barangay']}',
                  'Location: ${order.shippingAddress!['city']}, ${order.shippingAddress!['region']}',
                  'Postal Code: ${order.shippingAddress!['postal_code']}',
                ],
                Icons.location_on,
              )
            else
              const Text('No address snapshot found.', style: TextStyle(color: Colors.red)),

            const SizedBox(height: 24),

            // Shipping Option Snapshot
            const Text('Shipping Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
             if (order.shippingOption != null)
              _buildInfoCard(
                context,
                [
                  'Method: ${order.shippingOption!['name']}',
                  'Fee: ₱${order.shippingFee?.toStringAsFixed(2)}',
                  'Est. Delivery: ${order.shippingOption!['estimated_delivery'] ?? '3-5 days'}',
                ],
                Icons.local_shipping,
              )
            else
              const Text('No shipping option snapshot found.', style: TextStyle(color: Colors.red)),

            const SizedBox(height: 24),

            // Items List
            const Text('Order Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ...order.items.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(width: 40, height: 40, color: Colors.grey[200], child: const Icon(Icons.inventory)),
                title: Text(item.name),
                subtitle: Text('Qty: ${item.quantity}'),
                trailing: Text('₱${(item.price * item.quantity).toStringAsFixed(2)}', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )),

            const SizedBox(height: 24),

            // Order Totals
            _buildTotalRow('Subtotal', '₱${(order.totalPrice - (order.shippingFee ?? 0)).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildTotalRow('Shipping Fee', '₱${order.shippingFee?.toStringAsFixed(2)}'),
            const Divider(height: 32),
            _buildTotalRow('Total Amount', '₱${order.totalPrice.toStringAsFixed(2)}', isBold: true),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<String> lines, IconData icon) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: SwipifyTheme.primaryColor.withValues(alpha: 0.7)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(l, style: const TextStyle(fontSize: 14, height: 1.4)),
                )).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 18 : 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: isBold ? 20 : 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
            color: isBold ? SwipifyTheme.primaryColor : Colors.black87)),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.grey;
      case 'paid': return Colors.green[300]!;
      case 'processing': return Colors.blue;
      case 'shipped': return Colors.orange;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}
