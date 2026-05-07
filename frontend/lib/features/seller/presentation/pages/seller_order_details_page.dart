import 'package:flutter/material.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/services/shipping_service.dart';

class SellerOrderDetailsPage extends StatefulWidget {
  final OrderModel order;

  const SellerOrderDetailsPage({super.key, required this.order});

  @override
  State<SellerOrderDetailsPage> createState() => _SellerOrderDetailsPageState();
}

class _SellerOrderDetailsPageState extends State<SellerOrderDetailsPage> {
  late OrderModel _currentOrder;
  bool _isCreatingShipment = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(_currentOrder.status);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_currentOrder.id.substring(0, 8).toUpperCase()}'),
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
                         Text('Status: ${_currentOrder.status.toUpperCase()}', 
                           style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16)),
                         Text('Updated: ${_currentOrder.updatedAt?.substring(0, 10) ?? 'N/A'}', 
                           style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                       ],
                     )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_currentOrder.status.toLowerCase() == 'processing' || _currentOrder.status.toLowerCase() == 'pending')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingShipment ? null : () async {
                      setState(() => _isCreatingShipment = true);
                      try {
                        await ShippingService.createShipment(
                          orderId: _currentOrder.id,
                          courierId: 'jnt', // Defaulting to J&T for now, or could let seller choose
                        );
                        // We just pop and refresh
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shipment created successfully!')));
                        Navigator.pop(context, true); // Return true to signal refresh needed
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                      } finally {
                        if (mounted) setState(() => _isCreatingShipment = false);
                      }
                    },
                    icon: _isCreatingShipment ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.local_shipping),
                    label: Text(_isCreatingShipment ? 'Creating...' : 'Create Shipment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwipifyTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
            const SizedBox(height: 24),

            // Shipping Address Snapshot
            const Text('Shipping Address (Snapshot)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            if (_currentOrder.shippingAddress != null)
              _buildInfoCard(
                context,
                [
                  'Recipient: ${_currentOrder.shippingAddress!['full_name']}',
                  'Phone: ${_currentOrder.shippingAddress!['phone']}',
                  'Address: ${_currentOrder.shippingAddress!['street']}, ${_currentOrder.shippingAddress!['barangay']}',
                  'Location: ${_currentOrder.shippingAddress!['city']}, ${_currentOrder.shippingAddress!['region']}',
                  'Postal Code: ${_currentOrder.shippingAddress!['postal_code']}',
                ],
                Icons.location_on,
              )
            else
              const Text('No address snapshot found.', style: TextStyle(color: Colors.red)),

            const SizedBox(height: 24),

            // Shipping Option Snapshot
            const Text('Shipping Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
             if (_currentOrder.shippingOption != null)
              _buildInfoCard(
                context,
                [
                  'Method: ${_currentOrder.shippingOption!['name']}',
                  'Fee: ₱${_currentOrder.shippingFee?.toStringAsFixed(2)}',
                  'Est. Delivery: ${_currentOrder.shippingOption!['estimated_delivery'] ?? '3-5 days'}',
                ],
                Icons.local_shipping,
              )
            else
              const Text('No shipping option snapshot found.', style: TextStyle(color: Colors.red)),

            const SizedBox(height: 24),

            // Items List
            const Text('Order Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ..._currentOrder.items.map((item) => Card(
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
            _buildTotalRow('Subtotal', '₱${(_currentOrder.totalPrice - (_currentOrder.shippingFee ?? 0)).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildTotalRow('Shipping Fee', '₱${_currentOrder.shippingFee?.toStringAsFixed(2)}'),
            const Divider(height: 32),
            _buildTotalRow('Total Amount', '₱${_currentOrder.totalPrice.toStringAsFixed(2)}', isBold: true),
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
