import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/orders/order_service.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  late Future<List<OrderModel>> _futureOrders;
  List<OrderModel> _allOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  void _fetchOrders() {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      _futureOrders = OrderService.getSellerOrders(uid).then((orders) {
        setState(() {
          _allOrders = orders;
        });
        return orders;
      });
    } else {
      _futureOrders = Future.error('User not logged in');
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.black)),
      );

      await OrderService.updateOrderStatus(orderId, newStatus);
      
      if (mounted) Navigator.pop(context); // close loader
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order Status Updated to: ${newStatus.toUpperCase()}'),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchOrders(); // refresh the list
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: OrderModel.validStatuses.length + 1,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Store Orders', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.black,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              const Tab(text: 'ALL'),
              ...OrderModel.validStatuses.map((s) => Tab(text: s.toUpperCase())),
            ],
          ),
        ),
        body: FutureBuilder<List<OrderModel>>(
          future: _futureOrders,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _allOrders.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            } else if (snapshot.hasError && _allOrders.isEmpty) {
              return Center(child: Text('Error loading orders', style: GoogleFonts.outfit()));
            }

            return TabBarView(
              children: [
                _buildOrderList(_allOrders),
                ...OrderModel.validStatuses.map((status) => _buildOrderList(
                  _allOrders.where((o) => o.status.toLowerCase() == status).toList(),
                )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text('No orders here', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _fetchOrders(),
      color: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: orders.length,
        itemBuilder: (context, index) => _SellerOrderCard(
          order: orders[index],
          onStatusUpdate: (status) => _updateStatus(orders[index].id, status),
          statusColor: OrderModel.getStatusColor(orders[index].status),
        ),
      ),
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  final OrderModel order;
  final Function(String) onStatusUpdate;
  final Color statusColor;

  const _SellerOrderCard({required this.order, required this.onStatusUpdate, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(order.createdAt ?? '')?.toLocal();
    final dateStr = date != null ? DateFormat('MMM d, HH:mm').format(date) : 'Recently';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${order.id.substring(0, 8).toUpperCase()}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(dateStr, style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              _buildStatusBadge(),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
          
          // Customer Details
          Text('CUSTOMER', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(backgroundColor: Colors.grey.shade100, radius: 16, child: const Icon(Icons.person, size: 16, color: Colors.grey)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.shippingAddress?['full_name'] ?? 'Buyer', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(order.shippingAddress?['city'] ?? 'Address Hidden', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Items
          Text('ITEMS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 8),
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl ?? '',
                    width: 40, height: 40, fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey.shade100),
                    errorWidget: (c, u, e) => const Icon(Icons.shopping_bag, size: 20, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )),
          
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Total', style: GoogleFonts.outfit(fontWeight: FontWeight.w500, color: Colors.grey)),
              Text('₱${order.totalPrice.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildStatusDropdown(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(order.status.toUpperCase(), style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusDropdown() {
    final validStatuses = ['pending', 'processing', 'shipped', 'delivered', 'cancelled'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validStatuses.contains(order.status) ? order.status : 'pending',
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
          items: validStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
          onChanged: (val) {
            if (val != null && val != order.status) {
              onStatusUpdate(val);
            }
          },
        ),
      ),
    );
  }
}
