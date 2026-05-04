import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/profile/screens/order_details_screen.dart';
import 'package:swipify/features/cart/service/cart_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:swipify/services/review_service.dart';
import 'package:swipify/features/orders/service/order_provider.dart';
import 'package:swipify/features/orders/tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  final int initialTab;
  const OrdersScreen({super.key, this.initialTab = 0});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTab);
    _fetchOrders();
  }

  void _fetchOrders() {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      // Use microtask to avoid calling notifyListeners during build if we were using Provider.of
      // But here we are in initState, so it's fine.
      Future.microtask(() {
        if (mounted) {
          context.read<OrderProvider>().fetchUserOrders(uid);
        }
      });
    }
  }

  void _showReviewDialog(OrderModel order, OrderItemModel item) {
    int rating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20, left: 24, right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SwipifyTheme.borderColor, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text("Product Review", style: SwipifyTheme.heading2),
              const SizedBox(height: 8),
              Text(item.name, style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 30),
              
              // Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  onPressed: () => setModalState(() => rating = index + 1),
                  icon: Icon(
                    index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < rating ? const Color(0xFFD4AF37) : SwipifyTheme.borderColor,
                    size: 40,
                  ),
                )),
              ),
              const SizedBox(height: 24),
              
              TextField(
                controller: commentController,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: "Share your experience...",
                  hintStyle: GoogleFonts.inter(color: SwipifyTheme.textSecondary),
                  filled: true,
                  fillColor: SwipifyTheme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    setModalState(() => isSubmitting = true);
                    try {
                      final uid = context.read<AuthProvider>().user!.uid;
                      await ReviewService.submitReview(
                        userId: uid,
                        productId: item.productId,
                        orderId: order.id,
                        rating: rating,
                        comment: commentController.text,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text("Review submitted!", style: GoogleFonts.inter(fontWeight: FontWeight.w600)), 
                          backgroundColor: SwipifyTheme.primaryColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Failed to submit review"), 
                          backgroundColor: Colors.redAccent,
                        ));
                      }
                    } finally {
                      setModalState(() => isSubmitting = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwipifyTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: isSubmitting 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text("SUBMIT REVIEW", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SwipifyTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: SwipifyTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        return Scaffold(
          backgroundColor: SwipifyTheme.backgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: SwipifyTheme.backgroundColor,
            iconTheme: const IconThemeData(color: SwipifyTheme.textPrimary),
            centerTitle: false,
            title: Text(
              'Purchases',
              style: SwipifyTheme.heading2.copyWith(fontSize: 20),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: SwipifyTheme.primaryColor,
              indicatorWeight: 3,
              labelColor: SwipifyTheme.primaryColor,
              unselectedLabelColor: SwipifyTheme.textSecondary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: [
                _buildTab('All', orderProvider.orders.length),
                _buildTab('To Pay', orderProvider.toPayCount),
                _buildTab('To Ship', orderProvider.toShipCount),
                _buildTab('To Receive', orderProvider.toReceiveCount),
                _buildTab('Completed', orderProvider.completedCount),
              ],
            ),
          ),
          body: orderProvider.isLoading
              ? const Center(child: CircularProgressIndicator(color: SwipifyTheme.primaryColor))
              : orderProvider.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text('Failed to load orders', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary)),
                          const SizedBox(height: 8),
                          Text(orderProvider.error!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _OrdersList(orders: orderProvider.orders),
                        _OrdersList(orders: orderProvider.orders.where((o) => o.status == 'pending').toList()),
                        _OrdersList(orders: orderProvider.orders.where((o) => o.status == 'processing' || o.status == 'paid').toList()),
                        _OrdersList(orders: orderProvider.orders.where((o) => o.status == 'shipped' || o.status == 'in_transit' || o.status == 'delivered').toList()),
                        _OrdersList(orders: orderProvider.orders.where((o) => o.status == 'completed').toList()),
                      ],
                    ),
        );
      },
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  const _OrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: SwipifyTheme.glassShadow),
              child: Icon(Icons.shopping_bag_outlined, size: 48, color: SwipifyTheme.textSecondary.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 24),
            Text('No orders here yet', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        // Parent state handles fetch
      },
      color: SwipifyTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: orders.length,
        itemBuilder: (ctx, i) => _OrderCard(
          order: orders[i],
          onRatePressed: (item) {
            final state = context.findAncestorStateOfType<_OrdersScreenState>();
            state?._showReviewDialog(orders[i], item);
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final Function(OrderItemModel)? onRatePressed;
  const _OrderCard({required this.order, this.onRatePressed});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'paid': return Colors.green;
      case 'processing': return Colors.blue;
      case 'shipped': return Colors.deepPurple;
      case 'in_transit': return Colors.indigo;
      case 'delivered': return Colors.green;
      case 'completed': return Colors.teal;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstItem = order.items.isNotEmpty ? order.items.first : null;
    final statusColor = _getStatusColor(order.status);
    final date = DateTime.tryParse(order.createdAt ?? '')?.toLocal();
    final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date) : 'Recently';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderDetailsScreen(order: order),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: SwipifyTheme.glassShadow,
          border: Border.all(color: SwipifyTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORDER #${order.id.length > 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase()}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: SwipifyTheme.textPrimary, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(dateStr, style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: SwipifyTheme.borderColor)),
            
            // Items
            if (firstItem != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CachedNetworkImage(
                      imageUrl: firstItem.imageUrl ?? '',
                      width: 80, height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: SwipifyTheme.backgroundColor),
                      errorWidget: (context, url, error) => Container(
                        color: SwipifyTheme.backgroundColor,
                        child: const Icon(Icons.shopping_bag_outlined, color: SwipifyTheme.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstItem.name, 
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: SwipifyTheme.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.items.length} ${order.items.length > 1 ? 'items' : 'item'} • Variant: Default', 
                          style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₱${firstItem.price.toStringAsFixed(2)}', 
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: SwipifyTheme.primaryColor),
                            ),
                            Text(
                              'x${firstItem.quantity}',
                              style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 20),
            
            // Footer Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: SwipifyTheme.backgroundColor, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Text('Total Amount', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    '₱${order.totalPrice.toStringAsFixed(2)}', 
                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: SwipifyTheme.textPrimary),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                if (order.status.toLowerCase() == 'delivered')
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton(
                        onPressed: () async {
                          await context.read<OrderProvider>().updateOrderStatus(order.id, 'completed');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order completed!')));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text('CONFIRM RECEIPT', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                      ),
                    ),
                  )
                else if (order.status.toLowerCase() == 'completed')
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onRatePressed?.call(firstItem!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFB8860B)),
                              const SizedBox(width: 8),
                              Text("Rate Product", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFFB8860B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (order.trackingNumber != null && (order.status.toLowerCase() == 'shipped' || order.status.toLowerCase() == 'in_transit' || order.status.toLowerCase() == 'out_for_delivery'))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TrackingScreen(
                                orderId: order.id,
                                trackingNumber: order.trackingNumber!,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SwipifyTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text('TRACK ORDER', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final userId = context.read<AuthProvider>().user?.uid;
                      if (userId != null) {
                        final items = order.items.map((i) => {
                          'productId': i.productId,
                          'quantity': i.quantity,
                        }).toList();
                        await context.read<CartProvider>().reorderItems(userId, items);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Added to cart!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            backgroundColor: SwipifyTheme.primaryColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            action: SnackBarAction(
                              label: 'VIEW',
                              textColor: Colors.white,
                              onPressed: () {
                                Navigator.popUntil(context, (route) => route.isFirst);
                              },
                            ),
                          ));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwipifyTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('RE-ORDER', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
