import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/services/admin_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/features/admin/pages/admin_users_page.dart';
import 'package:swipify/features/admin/pages/admin_sellers_page.dart';
import 'package:swipify/features/admin/pages/admin_products_page.dart';
import 'package:swipify/features/admin/pages/admin_orders_page.dart';
import 'package:swipify/features/admin/pages/admin_finance_page.dart';
import 'package:swipify/features/admin/pages/admin_marketing_page.dart';
import 'package:swipify/features/admin/pages/admin_support_page.dart';
import 'package:swipify/features/admin/pages/admin_settings_page.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  final List<String> _menuItems = [
    'Command Center',
    'User Management',
    'Seller Management',
    'Product Moderation',
    'Order Control',
    'Finance Center',
    'Marketing Center',
    'Support & Disputes',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final stats = await AdminService.getDashboardStats();
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildCommandCenter();
      case 1:
        return const AdminUsersPage();
      case 2:
        return const AdminSellersPage();
      case 3:
        return const AdminProductsPage();
      case 4:
        return const AdminOrdersPage();
      case 5:
        return const AdminFinancePage();
      case 6:
        return const AdminMarketingPage();
      case 7:
        return const AdminSupportPage();
      case 8:
        return const AdminSettingsPage();
      default:
        return _buildCommandCenter();
    }
  }


  Widget _buildCommandCenter() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('Command Center', style: SwipifyTheme.heading1),
              Text(
                'Last updated: ${DateTime.now().toString().split('.')[0]}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // KPI Cards Grid - Consolidated into 2 rows on large screens
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 6;
              double childAspectRatio = 1.3;
              
              if (constraints.maxWidth < 1400) {
                crossAxisCount = 4;
                childAspectRatio = 1.4;
              }
              if (constraints.maxWidth < 1100) {
                crossAxisCount = 3;
                childAspectRatio = 1.5;
              }
              if (constraints.maxWidth < 800) {
                crossAxisCount = 2;
                childAspectRatio = 1.6;
              }
              if (constraints.maxWidth < 500) {
                crossAxisCount = 1;
                childAspectRatio = 2.0;
              }
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
                children: [
                  _buildKpiCard('Total Users', _stats['total_users']?.toString() ?? '0', Icons.people, Colors.blue),
                  _buildKpiCard('Total Sellers', _stats['total_sellers']?.toString() ?? '0', Icons.store, Colors.green),
                  _buildKpiCard('Total Orders', _stats['total_orders']?.toString() ?? '0', Icons.shopping_bag, Colors.orange),
                  _buildKpiCard('GMV', '₱${(_stats['gmv'] ?? 0).toStringAsFixed(2)}', Icons.monetization_on, Colors.purple),
                  _buildKpiCard('Revenue', '₱${(_stats['platform_revenue'] ?? 0).toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.teal),
                  _buildKpiCard('Active Listings', _stats['active_listings']?.toString() ?? '0', Icons.inventory, Colors.indigo),
                  
                  _buildKpiCard('Pending Products', _stats['pending_products']?.toString() ?? '0', Icons.hourglass_top, Colors.amber),
                  _buildKpiCard('Pending Sellers', _stats['pending_seller_approvals']?.toString() ?? '0', Icons.person_add, Colors.cyan),
                  _buildKpiCard('Support Tickets', _stats['support_tickets']?.toString() ?? '0', Icons.support_agent, Colors.deepOrange),
                  _buildKpiCard('Active Campaigns', _stats['active_campaigns']?.toString() ?? '0', Icons.campaign, Colors.pink),
                  _buildKpiCard('Disputes', _stats['disputes']?.toString() ?? '0', Icons.gavel, Colors.brown),
                  _buildKpiCard('Refunds', _stats['refund_requests']?.toString() ?? '0', Icons.assignment_return, Colors.red),
                ],
              );
            },
          ),

          
          const SizedBox(height: 32),
          // Chart Component
          Container(
            height: 300,
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Revenue Growth (30 Days)', style: SwipifyTheme.productTitle),
                const SizedBox(height: 24),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final weeklyData = List<num>.from(_stats['weekly_revenue'] ?? [0.0, 0.0, 0.0, 0.0]);
                      final maxVal = weeklyData.reduce((curr, next) => curr > next ? curr : next).toDouble();
                      final double dynamicMaxY = maxVal > 0 ? maxVal * 1.2 : 1000.0;

                      return BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: dynamicMaxY,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '₱${rod.toY.toStringAsFixed(2)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12);
                                  String text;
                                  switch (value.toInt()) {
                                    case 0: text = 'Week 1'; break;
                                    case 1: text = 'Week 2'; break;
                                    case 2: text = 'Week 3'; break;
                                    case 3: text = 'Week 4'; break;
                                    default: text = ''; break;
                                  }
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 4,
                                    child: Text(text, style: style),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true, 
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0 || value == dynamicMaxY) return const SizedBox.shrink();
                                  return SideTitleWidget(
                                    meta: meta,
                                    space: 8,
                                    child: Text(
                                      value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(4, (index) {
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: weeklyData.length > index ? weeklyData[index].toDouble() : 0.0,
                                  color: Colors.purple,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                )
                              ],
                            );
                          }),
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Icon(Icons.trending_up, color: Colors.green.withValues(alpha: 0.5), size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 1000;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: isMobile ? _buildSidebar(isDrawer: true) : null,
      appBar: isMobile 
        ? AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(_menuItems[_selectedIndex], style: SwipifyTheme.heading2),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.black),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: SwipifyTheme.primaryColor,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ],
          )
        : null,
      body: Row(
        children: [
          // Sidebar (Desktop)
          if (!isMobile) _buildSidebar(isDrawer: false),
          
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top App Bar (Desktop only)
                if (!isMobile)
                  Container(
                    height: 70,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _menuItems[_selectedIndex], 
                            style: SwipifyTheme.heading2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 16),
                        const CircleAvatar(
                          backgroundColor: SwipifyTheme.primaryColor,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                if (!isMobile) const Divider(height: 1),
                
                // Content
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar({required bool isDrawer}) {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: SwipifyTheme.primaryColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Swipify Admin',
                    style: SwipifyTheme.heading2.copyWith(fontSize: 20),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: SwipifyTheme.primaryColor.withValues(alpha: 0.1),
                  leading: Icon(
                    _getIconForIndex(index),
                    color: isSelected ? SwipifyTheme.primaryColor : Colors.grey.shade600,
                  ),
                  title: Text(
                    _menuItems[index],
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? SwipifyTheme.primaryColor : Colors.grey.shade800,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    if (isDrawer) {
                      Navigator.pop(context); // Close drawer
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.dashboard;
      case 1: return Icons.people;
      case 2: return Icons.store;
      case 3: return Icons.inventory;
      case 4: return Icons.shopping_cart;
      case 5: return Icons.account_balance;
      case 6: return Icons.campaign;
      case 7: return Icons.support_agent;
      case 8: return Icons.settings;
      default: return Icons.dashboard;
    }
  }
}
