import 'package:flutter/material.dart';
import 'package:swipify/services/admin_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/core/utils/responsive_helper.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('[ORDER CTRL] Loading orders with status=$_selectedStatus');
        final result = await AdminService.getOrders(
          status: _selectedStatus,
        );
        setState(() => _orders = result['orders'] ?? []);
        debugPrint('[ORDER CTRL] Loaded ${_orders.length} orders with resolved identities');
      }
    } catch (e) {
      debugPrint('[ORDER CTRL] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forceCancelOrder(String orderId, String reason) async {
    try {
      await AdminService.forceCancelOrder(orderId, reason);
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order force cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ORDER CTRL] Error cancelling: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCancelDialog(String orderId) {
    final reasonController = TextEditingController();
    String? errorText;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isMobile = ResponsiveHelper.isMobile(context);
          return AlertDialog(
            title: const Text('Force Cancel Order'),
            content: SizedBox(
              width: isMobile ? double.maxFinite : 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Force cancelling bypasses normal flows and may trigger refunds.',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'Enter reason for cancellation',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    setState(() => errorText = 'Reason is required');
                  } else if (reason.length < 10) {
                    setState(() => errorText = 'Reason must be at least 10 characters');
                  } else {
                    _forceCancelOrder(orderId, reason);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Confirm'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveHelper.isMobile(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, size: 28, color: Colors.teal),
                  const SizedBox(width: 12),
                  Text(
                    'Order Control Center',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedStatus,
                        hint: const Text('All Statuses'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All Statuses')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'paid', child: Text('Paid')),
                          DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                          DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                          DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                          _loadOrders();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadOrders,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? _buildShimmerList()
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No orders found',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return _buildOrderCard(order);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildShimmerList() {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, __) => Card(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 200, height: 14, color: Colors.grey.shade200),
                    const SizedBox(height: 6),
                    Container(width: 150, height: 12, color: Colors.grey.shade100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final bool isMobile = ResponsiveHelper.isMobile(context);
    final status = order['status'] ?? 'pending';
    final buyerName = order['buyer_name'] ?? 'Unknown Buyer';
    final sellerName = order['seller_name'] ?? 'Unknown Seller';
    final totalPrice = order['total_price'] ?? order['totalAmount'] ?? 0;
    final thumbnailUrl = order['thumbnail_url'];
    final itemCount = (order['items'] as List?)?.length ?? 0;
    final orderId = order['id'] ?? '';
    final createdAt = order['created_at'] ?? '';
    final isBuyerDeleted = buyerName == 'Deleted User';
    final isSellerDeleted = sellerName == 'Deleted Seller';
    final canCancel = status != 'cancelled' && status != 'refunded' && status != 'delivered';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product thumbnail
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: thumbnailUrl != null && thumbnailUrl.toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        thumbnailUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey.shade400, size: 24),
                      ),
                    )
                  : Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade400, size: 24),
            ),
            const SizedBox(width: 12),
            // Order info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '₱${_formatPrice(totalPrice)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Buyer/Seller Stack
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 12, color: isBuyerDeleted ? Colors.red : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          buyerName, 
                          style: TextStyle(fontSize: 11, color: isBuyerDeleted ? Colors.red : Colors.grey.shade800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.store_outlined, size: 12, color: isSellerDeleted ? Colors.red : Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sellerName, 
                          style: TextStyle(fontSize: 11, color: isSellerDeleted ? Colors.red : Colors.blue.shade700, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$itemCount item${itemCount > 1 ? 's' : ''} • ${_formatDate(createdAt)}', 
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status & Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusTag(status),
                if (canCancel) ...[
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                    onPressed: () => _showCancelDialog(orderId),
                    tooltip: 'Force Cancel',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    try {
      final p = double.parse(price.toString());
      return p.toStringAsFixed(2);
    } catch (_) {
      return '0.00';
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return Colors.blue;
      case 'shipped': return Colors.orange;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'refunded': return Colors.purple;
      case 'pending': return Colors.amber.shade700;
      default: return Colors.grey;
    }
  }
}
