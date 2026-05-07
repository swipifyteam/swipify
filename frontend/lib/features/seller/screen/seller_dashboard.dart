// lib/features/seller/screen/seller_dashboard.dart
// Seller Dashboard for Swipify.
// 🚨 PART 3, 6, 7 FIXES 🚨
// - Real Earnings (Sum of delivered orders)
// - Unique Order List (UUID v4 support)
// - No static/fake data
// - Fixed Overflows
// - Compact Drawer with EXIT logic

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:intl/intl.dart';
import 'package:swipify/features/seller/presentation/pages/seller_voucher_page.dart';
import 'package:swipify/features/seller/presentation/pages/edit_product_page.dart';
import 'package:swipify/screens/chat_list_screen.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  void _refreshData() {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoggedIn && auth.user != null) {
       final sellerId = auth.user!.uid;
       final prov = Provider.of<SellerProvider>(context, listen: false);
       prov.fetchDashboardData(sellerId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seller = Provider.of<SellerProvider>(context);

    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Seller Center", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: SwipifyTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: SwipifyTheme.primaryColor,
          indicatorWeight: 3,
          isScrollable: false, // Changed to false for better balance if only 3 tabs
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Orders"),
            Tab(text: "Products"),
            Tab(text: "Messages"),
          ],
        ),
      ),
      drawer: _buildCompactDrawer(context),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(seller),
          _buildOrdersTab(seller),
          _buildProductsTab(seller),
          const ChatListScreen(showAppBar: false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-product').then((_) => _refreshData()),
        backgroundColor: SwipifyTheme.primaryColor,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildCompactDrawer(BuildContext context) {
    return Drawer(
      width: 280, // Fixed width for consistent compact look
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // ULTRA COMPACT DRAWER HEADER
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SwipifyTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.storefront_rounded, color: SwipifyTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            "SELLER CENTER", 
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text("Management Portal", style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _drawerItem(Icons.dashboard_outlined, "Overview", 0),
                  _drawerItem(Icons.inventory_2_outlined, "Products", 2),
                  _drawerItem(Icons.receipt_long_outlined, "Orders", 1),
                  _drawerItem(Icons.chat_bubble_outline_rounded, "Messages", 3),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Divider()),
                  _drawerItem(Icons.campaign_outlined, "Marketing", -1),
                  _drawerItem(Icons.account_balance_wallet_outlined, "Finance", -1),
                  _drawerItem(Icons.settings_outlined, "Settings", -1),
                ],
              ),
            ),
            
            // EXIT BUTTON REPLACING LOGOUT
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: InkWell(
                onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                child: Row(
                  children: [
                    const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "EXIT AS SELLER", 
                        style: GoogleFonts.outfit(
                          color: Colors.redAccent, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int tabIndex) {

    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.black87, size: 22),
      title: Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        if (tabIndex != -1) {
          _tabController.animateTo(tabIndex);
        }
      },
    );
  }

  // ── OVERVIEW TAB ──────────────────────────────────────────
  Widget _buildOverviewTab(SellerProvider seller) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      color: SwipifyTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Shop Performance",
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(DateTime.now()),
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // EARNINGS HERO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1A1A1A), const Color(0xFF333333)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total Earnings", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text("WALLET", style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "₱${seller.totalEarnings.toStringAsFixed(2)}",
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _heroStatItem("Active Orders", "${seller.totalOrders}", Icons.shopping_bag_outlined)),
                        Container(width: 1, height: 30, color: Colors.white10),
                        Expanded(child: _heroStatItem("Delivered", "${seller.deliveredCount}", Icons.check_circle_outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Text("Management", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _managementCard("Vouchers", "Campaigns", Icons.confirmation_number_outlined, Colors.deepPurple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerVoucherPage()));
                }),
                _managementCard("Analytics", "Growth", Icons.auto_graph_rounded, Colors.blueAccent, () {}),
                _managementCard("Messages", "Customer Chat", Icons.chat_bubble_outline_rounded, Colors.orangeAccent, () {
                  _tabController.animateTo(3);
                }),
                _managementCard("Reviews", "Overall Rating", Icons.star_outline_rounded, Colors.amber, () {}),
              ],
            ),
            
            const SizedBox(height: 24),
            _buildRecentActivityList(seller),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _heroStatItem(String label, String val, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(val, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _managementCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(sub, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  // ── ORDERS TAB ──────────────────────────────────────────────
  Widget _buildOrdersTab(SellerProvider seller) {
    if (seller.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 60, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text("No orders yet", style: GoogleFonts.outfit(color: Colors.grey.shade400, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: seller.orders.length,
      itemBuilder: (context, index) {
        final order = seller.orders[index];
        final statusColor = _getStatusColor(order.status);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ORDER #${order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase()}", 
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade400)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(order.status.toUpperCase(), 
                        style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text("${order.items.length} Item(s)", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                    Text("₱${order.totalPrice.toStringAsFixed(2)}", 
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                  ],
                ),
              ),
              if (order.status.toLowerCase() != 'delivered' && order.status.toLowerCase() != 'cancelled')
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        String nextStatus = 'delivered';
                        if (order.status.toLowerCase() == 'pending') {
                          nextStatus = 'paid';
                        } else if (order.status.toLowerCase() == 'paid') {
                          nextStatus = 'processing';
                        } else if (order.status.toLowerCase() == 'processing') {
                          nextStatus = 'shipped';
                        } else if (order.status.toLowerCase() == 'shipped') {
                          nextStatus = 'delivered';
                        }
                        
                        seller.updateOrderStatus(order.id, nextStatus, auth.user!.uid);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(_getNextActionLabel(order.status), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getNextActionLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return 'PROCESS ORDER';
      case 'paid': return 'PREPARE ITEMS';
      case 'processing': return 'START SHIPPING';
      case 'shipped': return 'MARK DELIVERED';
      default: return 'MANAGE';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'paid': return Colors.blue;
      case 'processing': return Colors.indigo;
      case 'shipped': return Colors.deepPurple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  // ── PRODUCTS TAB ──────────────────────────────────────────────
  Widget _buildProductsTab(SellerProvider seller) {
    if (seller.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 60, color: Colors.grey.shade200),
            const SizedBox(height: 16),
            Text("No listings found", style: GoogleFonts.outfit(color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72, // Taller for long labels
      ),
      itemCount: seller.products.length,
      itemBuilder: (context, index) {
        final product = seller.products[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    image: DecorationImage(
                      image: NetworkImage(product.firstImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₱${product.price}",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: SwipifyTheme.primaryColor, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Stock: ${product.stock}", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10)),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => EditProductPage(product: product)),
                                ).then((_) => _refreshData());
                              },
                              child: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () => _confirmDelete(context, seller, product),
                              child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityList(SellerProvider seller) {
    final recentOrders = seller.orders.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Recent Activity", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: Text("See All", style: GoogleFonts.outfit(fontSize: 12, color: SwipifyTheme.primaryColor)),
            ),
          ],
        ),
        if (recentOrders.isEmpty) 
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text("No items to display", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
          ),
        ...recentOrders.map((o) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_rounded, size: 20, color: Colors.black54),
              ),
              title: Text("Sale of ₱${o.totalPrice.toStringAsFixed(2)}", style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text("Order #${o.id.length > 8 ? o.id.substring(0, 8) : o.id} • ${o.status}", style: GoogleFonts.outfit(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              onTap: () => _tabController.animateTo(1),
            )),
      ],
    );
  }

  void _confirmDelete(BuildContext context, SellerProvider seller, dynamic product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Product?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete ${product.name}?", style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              seller.deleteProduct(product.id, auth.user!.uid);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Product removed")),
              );
            },
            child: Text("DELETE", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

