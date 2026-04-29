// ignore_for_file: unused_import
// lib/features/seller/presentation/pages/seller_dashboard_page.dart
// Seller Center — Shopee-style side-nav dashboard
// Modules: Overview · Products · Orders · Marketing · Finance · Settings

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'package:image_picker/image_picker.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/seller/service/seller_products_provider.dart';
import 'package:swipify/features/seller/presentation/pages/seller_voucher_page.dart';
import 'package:swipify/features/seller/presentation/pages/marketing/flash_sales_page.dart';
import 'package:swipify/features/seller/presentation/pages/marketing/bundle_deals_page.dart';
import 'package:swipify/features/seller/presentation/pages/marketing/loyalty_points_page.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/services/api_service.dart';

// ─── Colour palette ──────────────────────────────────────────────────────────
const _kPrimary    = Color(0xFF36454F); // Charcoal
const _kAccent     = Color(0xFFE97B4A); // Warm orange  (highlight / CTA)
const _kSurface    = Color(0xFFF4F6F8);
const _kCard       = Color(0xFFFFFFFF);
const _kBorder     = Color(0xFFE0E4E9);
const _kTextPrimary    = Color(0xFF1A2332);

// ─── Relative time helper ────────────────────────────────────────────────────
String _timeAgo(String? isoString) {
  if (isoString == null || isoString.isEmpty) return '—';
  final dt = DateTime.tryParse(isoString);
  if (dt == null) return '—';
  final diff = DateTime.now().toUtc().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
  if (diff.inHours < 24) return '${diff.inHours} hr${diff.inHours == 1 ? '' : 's'} ago';
  if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  return DateFormat('MMM d, yyyy').format(dt.toLocal());
}
const _kTextSecondary  = Color(0xFF6B7A8D);
const _kGreen      = Color(0xFF27AE60);
const _kOrange     = Color(0xFFE97B4A);
const _kBlue       = Color(0xFF2D7DD2);
const _kPurple     = Color(0xFF8B5CF6);
const _kRed        = Color(0xFFE74C3C);

// ─── Sidebar items ────────────────────────────────────────────────────────────
enum _NavItem { overview, products, orders, marketing, finance, settings }

const _navDefs = [
  (_NavItem.overview,   Icons.dashboard_rounded,      'Overview'),
  (_NavItem.products,   Icons.inventory_2_rounded,    'Products'),
  (_NavItem.orders,     Icons.receipt_long_rounded,   'Orders'),
  (_NavItem.marketing,  Icons.campaign_rounded,       'Marketing'),
  (_NavItem.finance,    Icons.account_balance_wallet_rounded, 'Finance'),
  (_NavItem.settings,   Icons.settings_rounded,       'Settings'),
];

// ─────────────────────────────────────────────────────────────────────────────
class SellerDashboardPage extends StatefulWidget {
  const SellerDashboardPage({super.key});
  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> {
  _NavItem _active = _NavItem.overview;
  bool _sidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final auth = context.read<AuthProvider>();
    final uid  = auth.user?.uid;
    if (uid == null) return;
    context.read<SellerProvider>().fetchDashboardData(uid);
    context.read<SellerProductsProvider>().fetchSellerProducts(uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: Row(
        children: [
          _Sidebar(
            active: _active,
            expanded: _sidebarExpanded,
            onSelect: (item) => setState(() => _active = item),
            onToggle: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_active) {
      case _NavItem.overview:   return const _OverviewModule();
      case _NavItem.products:   return const _ProductsModule();
      case _NavItem.orders:     return const _OrdersModule();
      case _NavItem.marketing:  return const _MarketingModule();
      case _NavItem.finance:    return const _FinanceModule();
      case _NavItem.settings:   return const _SettingsModule();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIDEBAR
// ═══════════════════════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  final _NavItem active;
  final bool expanded;
  final ValueChanged<_NavItem> onSelect;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.active,
    required this.expanded,
    required this.onSelect,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.user?.displayName ?? 'My Shop';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: expanded ? 220 : 68,
      decoration: const BoxDecoration(
        color: _kPrimary,
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(2, 0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand / shop header
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 6),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kAccent, Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                InkWell(
                  onTap: onToggle,
                  child: Icon(
                    expanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF4A5A63)),
          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _navDefs.map((def) {
                  final (item, icon, label) = def;
                  return _NavTile(
                    icon: icon,
                    label: label,
                    isActive: active == item,
                    expanded: expanded,
                    onTap: () => onSelect(item),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF4A5A63)),
          _NavTile(
            icon: Icons.exit_to_app_rounded,
            label: 'EXIT AS SELLER',
            isActive: false,
            expanded: expanded,
            onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
            danger: true,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool expanded;
  final VoidCallback onTap;
  final bool danger;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.expanded,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFFF6B6B) : isActive ? Colors.white : Colors.white60;
    return Tooltip(
      message: !expanded ? label : '',
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive ? Border.all(color: _kAccent.withValues(alpha: 0.5), width: 1) : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: isActive ? _kAccent : fg, size: 20),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(color: fg, fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Standard top bar used by every module
class _ModuleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showDate;
  const _ModuleBar({required this.title, this.actions, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: _kCard,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title, 
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _kTextPrimary),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
          if (showDate) ...[
            if (actions != null && actions!.isNotEmpty) const SizedBox(width: 16),
            Text(
              DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
              style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

/// KPI stat card
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _kTextPrimary)),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: GoogleFonts.inter(fontSize: 11, color: _kGreen, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// Generic section header inside module body
class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _kTextPrimary)),
    const Spacer(),
    ?trailing,
  ]);
}

Widget _pillBadge(String text, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: bg)),
    );

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE 1 ── OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════════
class _OverviewModule extends StatelessWidget {
  const _OverviewModule();

  @override
  Widget build(BuildContext context) {
    final sp  = context.watch<SellerProvider>();
    final spp = context.watch<SellerProductsProvider>();
    final fmt = NumberFormat('#,##0.00');
    final orders = sp.orders;
    final pending   = orders.where((o) => o.status == 'pending').length;
    final shipped   = orders.where((o) => o.status == 'shipped').length;
    final delivered = orders.where((o) => o.status == 'delivered').length;
    final lowStock  = spp.products.where((p) => p.stock < 10).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ModuleBar(title: 'Overview', showDate: true),
        Expanded(
          child: sp.isLoading
              ? const Center(child: CircularProgressIndicator(color: _kAccent))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // KPI row
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 180,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StatCard(
                          label: 'Total Revenue',
                          value: '₱${fmt.format(sp.totalEarnings)}',
                          sub: 'From delivered orders',
                          icon: Icons.payments_rounded,
                          color: _kGreen,
                        ),
                        _StatCard(
                          label: 'Total Orders',
                          value: '${sp.totalOrders}',
                          sub: '$pending pending',
                          icon: Icons.shopping_bag_rounded,
                          color: _kBlue,
                        ),
                        _StatCard(
                          label: 'Active Products',
                          value: '${spp.products.length}',
                          sub: lowStock > 0 ? '$lowStock low-stock' : null,
                          icon: Icons.inventory_2_rounded,
                          color: _kPurple,
                        ),
                        _StatCard(
                          label: 'Completed Orders',
                          value: '$delivered',
                          sub: '$shipped shipped',
                          icon: Icons.check_circle_rounded,
                          color: _kOrange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent orders section
                    const _SectionHeader(title: 'Recent Orders'),
                    const SizedBox(height: 12),
                    orders.isEmpty
                        ? _emptyBox('No orders yet')
                        : Column(
                            children: orders.take(5).map((o) => _OrderRow(order: o)).toList(),
                          ),
                    const SizedBox(height: 24),

                    // Low stock alerts
                    if (lowStock > 0) ...[
                      _SectionHeader(
                        title: 'Low Stock Alerts',
                        trailing: _pillBadge('$lowStock items', _kRed),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: spp.products
                            .where((p) => p.stock < 10)
                            .take(5)
                            .map((p) => _LowStockRow(product: p))
                            .toList(),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

Widget _emptyBox(String msg) => Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(msg, style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 14)),
          ],
        ),
      ),
    );

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = OrderModel.getStatusColor(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _kTextPrimary)),
                const SizedBox(height: 2),
                Text(_timeAgo(order.createdAt),
                    style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text('${order.items.length} item${order.items.length > 1 ? 's' : ''}',
              style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 12)),
          const SizedBox(width: 16),
          Text('₱${NumberFormat('#,##0.00').format(order.totalPrice)}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _kTextPrimary)),
          const SizedBox(width: 16),
          _pillBadge(order.formattedStatus, color),
        ],
      ),
    );
  }
}

class _LowStockRow extends StatelessWidget {
  final ProductModel product;
  const _LowStockRow({required this.product});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(product.primaryImage, width: 40, height: 40, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(width: 40, height: 40, color: _kSurface,
                    child: const Icon(Icons.image_not_supported_rounded, color: _kBorder))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(product.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: product.stock == 0 ? _kRed.withValues(alpha: 0.12) : _kOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              product.stock == 0 ? 'OUT OF STOCK' : '${product.stock} left',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                  color: product.stock == 0 ? _kRed : _kOrange),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE 2 ── PRODUCTS
// ═══════════════════════════════════════════════════════════════════════════════
class _ProductsModule extends StatefulWidget {
  const _ProductsModule();
  @override
  State<_ProductsModule> createState() => _ProductsModuleState();
}

class _ProductsModuleState extends State<_ProductsModule> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  final Set<String> _selected = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spp = context.watch<SellerProductsProvider>();
    final auth = context.read<AuthProvider>();
    final uid  = auth.user?.uid ?? '';

    // Client-side filter results
    List<ProductModel> displayed = spp.products.where((p) {
      final matchSearch = _searchCtrl.text.isEmpty ||
          p.name.toLowerCase().contains(_searchCtrl.text.toLowerCase());
      final matchCat = _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchStatus = _selectedStatus == 'All' ||
          (_selectedStatus == 'Active' && p.isPublished) ||
          (_selectedStatus == 'Inactive' && !p.isPublished);
      return matchSearch && matchCat && matchStatus;
    }).toList();

    final categories = ['All', ...{...spp.products.map((p) => p.category)}];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModuleBar(
          title: 'Products (${spp.products.length})',
          actions: [
            if (_selected.isNotEmpty) ...[
              _ActionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Delete (${_selected.length})',
                color: _kRed,
                onPressed: () => _bulkDelete(spp, uid),
              ),
              const SizedBox(width: 8),
            ],
            _ActionButton(
              icon: Icons.add_rounded,
              label: 'Add Product',
              color: _kAccent,
              onPressed: () => _openAddProduct(context, uid),
            ),
          ],
        ),

        // Filter bar
        Container(
          color: _kCard,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              // Search
              SizedBox(
                width: 260,
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search products…',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _kTextSecondary),
                    filled: true,
                    fillColor: _kSurface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _FilterChipRow(
                label: 'Category',
                options: categories,
                value: _selectedCategory,
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(width: 12),
              _FilterChipRow(
                label: 'Status',
                options: ['All', 'Active', 'Inactive'],
                value: _selectedStatus,
                onChanged: (v) => setState(() => _selectedStatus = v),
              ),
              const Spacer(),
              Text('${displayed.length} results',
                  style: GoogleFonts.inter(color: _kTextSecondary, fontSize: 12)),
            ],
          ),
        ),
        const Divider(height: 1, color: _kBorder),

        // Table
        Expanded(
          child: spp.isLoading
              ? const Center(child: CircularProgressIndicator(color: _kAccent))
              : displayed.isEmpty
                  ? _emptyBox('No products found')
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Table header
                          _ProductTableHeader(
                            allSelected: _selected.length == displayed.length && displayed.isNotEmpty,
                            onSelectAll: (v) {
                              setState(() {
                                if (v == true) { _selected.addAll(displayed.map((p) => p.id)); }
                                else { _selected.clear(); }
                              });
                            },
                          ),
                          const SizedBox(height: 4),
                          ...displayed.map((p) => _ProductTableRow(
                            product: p,
                            isSelected: _selected.contains(p.id),
                            onSelect: (v) {
                              setState(() { v == true ? _selected.add(p.id) : _selected.remove(p.id); });
                            },
                            onEdit: () => _openEditProduct(context, p, uid),
                            onDelete: () => _confirmDelete(spp, p.id, uid),
                            onTogglePublish: () {
                              spp.updateProduct(p.id, {'is_published': !p.isPublished});
                            },
                          )),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  void _openAddProduct(BuildContext context, String uid) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const _ProductFormPage(),
    )).then((_) {
      if (!context.mounted) return;
      context.read<SellerProductsProvider>().fetchSellerProducts(uid);
    });
  }

  void _openEditProduct(BuildContext context, ProductModel product, String uid) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ProductFormPage(product: product),
    )).then((_) {
      if (!context.mounted) return;
      context.read<SellerProductsProvider>().fetchSellerProducts(uid);
    });
  }

  void _confirmDelete(SellerProductsProvider spp, String productId, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Product?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('This cannot be undone.', style: GoogleFonts.inter(color: _kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); spp.deleteProduct(productId); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _bulkDelete(SellerProductsProvider spp, String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete ${_selected.length} products?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('This cannot be undone.', style: GoogleFonts.inter(color: _kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in _selected) { await spp.deleteProduct(id); }
      _selected.clear();
      if (mounted) setState(() {});
    }
  }
}

class _FilterChipRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterChipRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => options
          .map((o) => PopupMenuItem(value: o, child: Text(o, style: GoogleFonts.inter(fontSize: 13))))
          .toList(),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ', style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary)),
            Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextPrimary)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: _kTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _ProductTableHeader extends StatelessWidget {
  final bool allSelected;
  final ValueChanged<bool?> onSelectAll;
  const _ProductTableHeader({required this.allSelected, required this.onSelectAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Checkbox(value: allSelected, onChanged: onSelectAll, activeColor: _kAccent),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: Text('PRODUCT', style: _headerStyle)),
          Expanded(flex: 1, child: Text('CATEGORY', style: _headerStyle)),
          Expanded(flex: 1, child: Text('PRICE', style: _headerStyle)),
          Expanded(flex: 1, child: Text('STOCK', style: _headerStyle)),
          Expanded(flex: 1, child: Text('STATUS', style: _headerStyle)),
          SizedBox(width: 120, child: Text('ACTIONS', style: _headerStyle)),
        ],
      ),
    );
  }

  static final _headerStyle = GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w700, color: _kTextSecondary, letterSpacing: 0.5,
  );
}

class _ProductTableRow extends StatelessWidget {
  final ProductModel product;
  final bool isSelected;
  final ValueChanged<bool?> onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublish;

  const _ProductTableRow({
    required this.product,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
  });

  @override
  Widget build(BuildContext context) {
    final stockColor = product.stock == 0 ? _kRed : product.stock < 10 ? _kOrange : _kGreen;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? _kAccent.withValues(alpha: 0.04) : _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSelected ? _kAccent.withValues(alpha: 0.4) : _kBorder),
      ),
      child: Row(
        children: [
          Checkbox(value: isSelected, onChanged: onSelect, activeColor: _kAccent),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(product.primaryImage, width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 44, height: 44, color: _kSurface,
                          child: const Icon(Icons.image_rounded, color: _kBorder))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary),
                          overflow: TextOverflow.ellipsis),
                      Text('SKU: ${product.id.substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.inter(fontSize: 10, color: _kTextSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 1,
            child: Text(product.category, style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary))),
          Expanded(flex: 1,
            child: Text('₱${NumberFormat('#,##0.00').format(product.price)}',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextPrimary))),
          Expanded(flex: 1,
            child: Row(children: [
              Icon(Icons.circle, size: 8, color: stockColor),
              const SizedBox(width: 4),
              Text('${product.stock}', style: GoogleFonts.inter(fontSize: 13, color: stockColor, fontWeight: FontWeight.w600)),
            ])),
          Expanded(flex: 1,
            child: _pillBadge(product.isPublished ? 'Active' : 'Inactive',
                product.isPublished ? _kGreen : _kTextSecondary)),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Tooltip(
                  message: product.isPublished ? 'Unpublish' : 'Publish',
                  child: InkWell(
                    onTap: onTogglePublish,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        product.isPublished ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18, color: _kTextSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Edit',
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_rounded, size: 18, color: _kBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Delete',
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_rounded, size: 18, color: _kRed),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE 3 ── ORDERS
// ═══════════════════════════════════════════════════════════════════════════════
class _OrdersModule extends StatefulWidget {
  const _OrdersModule();
  @override
  State<_OrdersModule> createState() => _OrdersModuleState();
}

class _OrdersModuleState extends State<_OrdersModule>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  static const _statuses = [
    'all', 'pending', 'processing', 'shipped', 'delivered', 'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SellerProvider>();

    return Column(
      children: [
        _ModuleBar(
          title: 'Orders',
          actions: [
            _ActionButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              color: _kPrimary,
              onPressed: () {
                final uid = context.read<AuthProvider>().user?.uid;
                if (uid != null) context.read<SellerProvider>().fetchOrders(uid);
              },
            ),
          ],
        ),
        Container(
          color: _kCard,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            labelColor: _kAccent,
            unselectedLabelColor: _kTextSecondary,
            indicatorColor: _kAccent,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
            tabs: _statuses.map((s) {
              final count = s == 'all'
                  ? sp.orders.length
                  : sp.orders.where((o) => o.status == s).length;
              return Tab(text: '${s[0].toUpperCase()}${s.substring(1)} ($count)');
            }).toList(),
          ),
        ),
        const Divider(height: 1, color: _kBorder),
        Expanded(
          child: sp.isLoading
              ? const Center(child: CircularProgressIndicator(color: _kAccent))
              : TabBarView(
                  controller: _tabs,
                  children: _statuses.map((s) {
                    final filtered = s == 'all'
                        ? sp.orders
                        : sp.orders.where((o) => o.status == s).toList();
                    return filtered.isEmpty
                        ? _emptyBox('No ${s == 'all' ? '' : '$s '}orders')
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _OrderCard(order: filtered[i]),
                          );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = OrderModel.getStatusColor(order.status);
    final sp = context.read<SellerProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text('#${order.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextPrimary)),
                const SizedBox(width: 10),
                _pillBadge(order.formattedStatus, statusColor),
                const Spacer(),
                Text(
                  _timeAgo(order.createdAt),
                  style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                ),
              ],
            ),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: order.items.take(2).map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: _kTextSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.name,
                          style: GoogleFonts.inter(fontSize: 13, color: _kTextPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('x${item.quantity}',
                        style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary)),
                    const SizedBox(width: 10),
                    Text('₱${NumberFormat('#,##0.00').format(item.price * item.quantity)}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )).toList(),
            ),
          ),

          if (order.trackingNumber != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, size: 14, color: _kPurple),
                  const SizedBox(width: 6),
                  Text(
                    '${order.logisticProvider ?? 'Courier'}: ${order.trackingNumber}',
                    style: GoogleFonts.inter(fontSize: 12, color: _kPurple, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, color: _kBorder),

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text('Total: ',
                    style: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary)),
                Text('₱${NumberFormat('#,##0.00').format(order.totalPrice)}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _kAccent)),
                const Spacer(),
                _NextStatusButton(order: order, uid: uid, sp: sp),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStatusButton extends StatelessWidget {
  final OrderModel order;
  final String uid;
  final SellerProvider sp;
  const _NextStatusButton({required this.order, required this.uid, required this.sp});

  static const _transitions = {
    'pending': 'processing',
    'paid': 'processing',
    'processing': 'shipped',
    'shipped': 'delivered',
    'delivered': 'completed',
  };

  @override
  Widget build(BuildContext context) {
    final next = _transitions[order.status];
    if (next == null) return const SizedBox.shrink();

    return ElevatedButton.icon(
      onPressed: () => sp.updateOrderStatus(order.id, next, uid, context: context),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
      label: Text('Mark as ${next[0].toUpperCase()}${next.substring(1)}'),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE 4 ── MARKETING
// ═══════════════════════════════════════════════════════════════════════════════
class _MarketingModule extends StatelessWidget {
  const _MarketingModule();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModuleBar(
          title: 'Marketing',
          actions: [
            _ActionButton(
              icon: Icons.confirmation_number_rounded,
              label: 'Manage Vouchers',
              color: _kAccent,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SellerVoucherPage(),
              )),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Promo tiles
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 2 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 90,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MarketingCard(
                    icon: Icons.confirmation_number_rounded,
                    title: 'Vouchers',
                    subtitle: 'Create & manage discount codes',
                    color: _kBlue,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SellerVoucherPage(),
                    )),
                  ),
                  _MarketingCard(
                    icon: Icons.flash_on_rounded,
                    title: 'Flash Sales',
                    subtitle: 'Time-limited promotional pricing',
                    color: _kOrange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const FlashSalesPage(),
                    )),
                  ),
                  _MarketingCard(
                    icon: Icons.local_offer_rounded,
                    title: 'Bundle Deals',
                    subtitle: 'Buy X get Y promotions',
                    color: _kPurple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const BundleDealsPage(),
                    )),
                  ),
                  _MarketingCard(
                    icon: Icons.star_rate_rounded,
                    title: 'Loyalty Points',
                    subtitle: 'Reward repeat customers',
                    color: _kGreen,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const LoyaltyPointsPage(),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _MarketingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MarketingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE 5 ── FINANCE
// ═══════════════════════════════════════════════════════════════════════════════
class _FinanceModule extends StatelessWidget {
  const _FinanceModule();

  @override
  Widget build(BuildContext context) {
    final sp  = context.watch<SellerProvider>();
    final fmt = NumberFormat('#,##0.00');
    final delivered = sp.orders.where((o) => o.status == 'delivered' || o.status == 'completed').toList();
    final pending   = sp.orders.where((o) => o.status == 'processing' || o.status == 'shipped').toList();

    return Column(
      children: [
        _ModuleBar(
          title: 'Finance',
          actions: [
            _ActionButton(
              icon: Icons.download_rounded,
              label: 'Export CSV',
              color: _kBlue,
              onPressed: () => _downloadReport(context, sp),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Balance overview cards
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 180,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    label: 'Total Earnings',
                    value: '₱${fmt.format(sp.totalEarnings)}',
                    sub: 'From completed deliveries',
                    icon: Icons.account_balance_wallet_rounded,
                    color: _kGreen,
                  ),
                  _StatCard(
                    label: 'In Transit',
                    value: '₱${fmt.format(pending.fold(0.0, (s, o) => s + o.totalPrice))}',
                    sub: '${pending.length} orders processing',
                    icon: Icons.hourglass_top_rounded,
                    color: _kOrange,
                  ),
                  _StatCard(
                    label: 'Orders Completed',
                    value: '${delivered.length}',
                    sub: 'Total delivered',
                    icon: Icons.check_circle_outline_rounded,
                    color: _kBlue,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Earnings history
              _SectionHeader(
                title: 'Earnings History',
                trailing: _pillBadge('${delivered.length} transactions', _kGreen),
              ),
              const SizedBox(height: 12),
              delivered.isEmpty
                  ? _emptyBox('No completed earnings yet')
                  : Column(
                      children: delivered.take(20).map((o) => _EarningsRow(order: o)).toList(),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EarningsRow extends StatelessWidget {
  final OrderModel order;
  const _EarningsRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final date = _timeAgo(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_downward_rounded, color: _kGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _kTextPrimary)),
                Text(date, style: GoogleFonts.inter(fontSize: 11, color: _kTextSecondary)),
              ],
            ),
          ),
          _pillBadge(order.formattedStatus, OrderModel.getStatusColor(order.status)),
          const SizedBox(width: 16),
          Text('+₱${NumberFormat('#,##0.00').format(order.totalPrice)}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _kGreen)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE 6 ── SETTINGS
// ═══════════════════════════════════════════════════════════════════════════════
class _SettingsModule extends StatefulWidget {
  const _SettingsModule();
  @override
  State<_SettingsModule> createState() => _SettingsModuleState();
}

class _SettingsModuleState extends State<_SettingsModule> {
  bool _vacationMode = false;
  final _storeNameCtrl = TextEditingController();
  final _storeDescCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _bannerUrlCtrl = TextEditingController();
  bool _isUploadingLogo = false;
  bool _isUploadingBanner = false;

  @override
  void initState() {
    super.initState();
    final sp = context.read<SellerProvider>();
    _storeNameCtrl.text = sp.shopName;
    _storeDescCtrl.text = sp.shopDescription;
    _logoUrlCtrl.text   = sp.logoUrl ?? '';
    _bannerUrlCtrl.text = sp.bannerUrl ?? '';
    _vacationMode = sp.vacationMode;
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _storeDescCtrl.dispose();
    _logoUrlCtrl.dispose();
    _bannerUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await ApiService.uploadProductImage(bytes, 'logo_${image.name}', uid);
      setState(() {
        _logoUrlCtrl.text = url;
        _isUploadingLogo = false;
      });
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logo upload failed: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() => _isUploadingBanner = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await ApiService.uploadProductImage(bytes, 'banner_${image.name}', uid);
      setState(() {
        _bannerUrlCtrl.text = url;
        _isUploadingBanner = false;
      });
    } catch (e) {
      setState(() => _isUploadingBanner = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Banner upload failed: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ModuleBar(title: 'Settings'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _SettingsSection(
                title: 'Shop Information',
                children: [
                  _SettingRow(
                    label: 'Store Name',
                    child: SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _storeNameCtrl,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: _settingInputDec('Enter store name'),
                      ),
                    ),
                  ),
                  _SettingRow(
                    label: 'Description',
                    sub: 'Tell customers about your shop',
                    child: SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _storeDescCtrl,
                        maxLines: 3,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: _settingInputDec('Describe your shop...'),
                      ),
                    ),
                  ),
                  _SettingRow(
                    label: 'Shop Logo',
                    sub: 'Displays on your shop profile',
                    child: SizedBox(
                      width: 280,
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingLogo ? null : _pickLogo,
                        icon: _isUploadingLogo
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                        label: Text(_isUploadingLogo ? 'Uploading...' : (_logoUrlCtrl.text.isEmpty ? 'Upload Logo' : 'Change Logo')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kTextPrimary,
                          side: BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  _SettingRow(
                    label: 'Shop Banner',
                    sub: 'Background for your store header',
                    child: SizedBox(
                      width: 280,
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingBanner ? null : _pickBanner,
                        icon: _isUploadingBanner
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                        label: Text(_isUploadingBanner ? 'Uploading...' : (_bannerUrlCtrl.text.isEmpty ? 'Upload Banner' : 'Change Banner')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kTextPrimary,
                          side: BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                  _SettingRow(
                    label: 'Vacation Mode',
                    sub: 'Temporarily pause your shop from receiving orders',
                    child: Switch(
                      value: _vacationMode,
                      onChanged: (v) => setState(() => _vacationMode = v),
                      activeThumbColor: _kAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Shipping Fees (Standard)',
                children: [
                   _SettingRow(
                    label: 'Standard Shipping Fee',
                    child: SizedBox(
                      width: 120,
                      child: TextFormField(
                        initialValue: context.read<SellerProvider>().standardShippingFee.toString(),
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: _settingInputDec('Price'),
                        onChanged: (v) => context.read<SellerProvider>().setStandardShippingFee(double.tryParse(v) ?? 120.0),
                      ),
                    ),
                  ),
                  _SettingRow(
                    label: 'Free Shipping Threshold',
                    sub: 'Set to 0 to disable',
                    child: SizedBox(
                      width: 120,
                      child: TextFormField(
                        initialValue: context.read<SellerProvider>().freeShippingThreshold.toString(),
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(fontSize: 13),
                        decoration: _settingInputDec('Min Spend'),
                        onChanged: (v) => context.read<SellerProvider>().setFreeShippingThreshold(double.tryParse(v) ?? 0.0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final sp = context.read<SellerProvider>();
                    final auth = context.read<AuthProvider>();
                    final uid = auth.user?.uid;
                    if (uid == null) return;
                    
                    final success = await sp.saveShopSettings(uid, {
                      'shop_name': _storeNameCtrl.text.trim(),
                      'description': _storeDescCtrl.text.trim(),
                      'logo_url': _logoUrlCtrl.text.trim(),
                      'banner_url': _bannerUrlCtrl.text.trim(),
                      'vacation_mode': _vacationMode,
                      'shipping_settings': {
                        'standard_fee': sp.standardShippingFee,
                        'express_fee': sp.expressShippingFee,
                        'free_threshold': sp.freeShippingThreshold,
                      }
                    });
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '✅ Shop settings updated successfully' : '❌ Failed to update settings'), 
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: success ? _kGreen : _kRed,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  child: const Text('Save Shop Profile'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _settingInputDec(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: _kSurface,
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kAccent)),
    );
  }

}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextPrimary)),
          ),
          const Divider(height: 20, indent: 20, endIndent: 20),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String? sub;
  final Widget child;
  const _SettingRow({required this.label, this.sub, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!, style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary)),
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRODUCT FORM (Add + Edit)  — inline in same route stack
// ═══════════════════════════════════════════════════════════════════════════════
class _ProductFormPage extends StatefulWidget {
  final ProductModel? product;
  const _ProductFormPage({this.product});

  @override
  State<_ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<_ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _weightCtrl;

  List<String> _images = [];
  String _category = '';
  bool _isPublished = true;
  bool _isSaving = false;
  bool _isUploading = false;
  List<String> _categories = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl   = TextEditingController(text: p?.name ?? '');
    _priceCtrl  = TextEditingController(text: p?.price.toString() ?? '');
    _stockCtrl  = TextEditingController(text: p?.stock.toString() ?? '');
    _descCtrl   = TextEditingController(text: p?.description ?? '');
    _skuCtrl    = TextEditingController(text: p?.id.substring(0, 8).toUpperCase() ?? '');
    _weightCtrl = TextEditingController(text: '0.5');
    _images     = List<String>.from(p?.images ?? []);
    _category   = p?.category ?? '';
    _isPublished = p?.isPublished ?? true;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    _skuCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await ApiService.uploadProductImage(bytes, image.name, uid);
      setState(() {
        _images.add(url);
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Product' : 'Add New Product',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: details form
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formSection('Basic Information', [
                      _field(controller: _nameCtrl, label: 'Product Name *',
                          validator: (v) => v?.isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 14),
                      _field(controller: _descCtrl, label: 'Description *',
                          maxLines: 4,
                          validator: (v) => v?.isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 14),
                      // Category
                      DropdownButtonFormField<String>(
                        initialValue: (_categories.contains(_category) && _category.isNotEmpty) ? _category : null,
                        items: _categories.isEmpty
                            ? [const DropdownMenuItem(value: 'General', child: Text('General'))]
                            : _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _category = v ?? ''),
                        decoration: _inputDec('Category *'),
                        validator: (v) => (v == null && _category.isEmpty) ? 'Required' : null,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _formSection('Pricing & Inventory', [
                      Row(children: [
                        Expanded(
                          child: _field(controller: _priceCtrl, label: 'Price (₱) *',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.isEmpty == true) return 'Required';
                                if (double.tryParse(v!) == null) return 'Invalid';
                                return null;
                              }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(controller: _stockCtrl, label: 'Stock Qty *',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.isEmpty == true) return 'Required';
                                if (int.tryParse(v!) == null) return 'Invalid';
                                return null;
                              }),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: _field(controller: _skuCtrl, label: 'SKU',
                              validator: null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(controller: _weightCtrl, label: 'Weight (kg)',
                              keyboardType: TextInputType.number,
                              validator: null),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 16),
                    _formSection('Visibility', [
                      SwitchListTile(
                        value: _isPublished,
                        onChanged: (v) => setState(() => _isPublished = v),
                        title: Text('Published', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _isPublished ? 'Visible to customers' : 'Hidden from customers',
                          style: GoogleFonts.inter(fontSize: 12, color: _kTextSecondary),
                        ),
                        activeThumbColor: _kAccent,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            const VerticalDivider(width: 1, color: _kBorder),

            // Right: images + save
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Product Images', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 12),

                    // Add Image button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _pickImage,
                        icon: _isUploading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_a_photo_rounded, size: 20),
                        label: Text(_isUploading ? 'Uploading...' : 'Upload Image'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          foregroundColor: _kTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Image grid
                    if (_images.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(_images[i], fit: BoxFit.cover,
                                  width: double.infinity, height: double.infinity,
                                  errorBuilder: (_, _, _) => Container(
                                    color: _kSurface,
                                    child: const Icon(Icons.broken_image_rounded, color: _kBorder),
                                  )),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: InkWell(
                                onTap: () => setState(() => _images.removeAt(i)),
                                child: Container(
                                  decoration: BoxDecoration(color: _kRed, borderRadius: BorderRadius.circular(30)),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccent, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_isEdit ? 'Save Changes' : 'Add Product'),
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

  Widget _formSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _kTextPrimary)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 13),
      decoration: _inputDec(label),
      validator: validator,
    );
  }

  InputDecoration _inputDec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: _kTextSecondary),
      filled: true,
      fillColor: _kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kAccent, width: 1.5)),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one image'), backgroundColor: _kRed),
      );
      return;
    }
    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final uid  = auth.user?.uid ?? '';
    final spp  = context.read<SellerProductsProvider>();

    final data = {
      'sellerId': uid,
      'seller_id': uid,
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'category': _category,
      'price': double.parse(_priceCtrl.text.trim()),
      'stock': int.parse(_stockCtrl.text.trim()),
      'images': _images,
      'is_published': _isPublished,
    };

    bool success;
    if (_isEdit) {
      success = await spp.updateProduct(widget.product!.id, data);
    } else {
      success = await spp.addProduct(data);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Product updated' : 'Product added'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _kGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(spp.error ?? 'Failed to save product'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _kRed,
          ),
        );
      }
    }
  }
}

// ─── Utility ──────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    );
  }
}

Future<void> _downloadReport(BuildContext context, SellerProvider sp) async {
  final authProvider = context.read<AuthProvider>();
  final sellerId = authProvider.user?.uid;
  if (sellerId == null) return;

  final url = sp.getSalesReportUrl(sellerId);
  final uri = Uri.parse(url);

  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sales report download triggered'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      throw 'Could not launch download link';
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Download failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE74C3C), // _kRed
        ),
      );
    }
  }
}

