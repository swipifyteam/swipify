// features/navigation/categories_screen.dart
// Redesign — 2-col product grid with filter chips, sort sheet,
// and consistent card design.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/services/api_service.dart';
import 'package:swipify/widgets/product_card.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<String> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() { super.initState(); _loadCategories(); }

  Future<void> _loadCategories() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      var cats = await ApiService.getCategories();
      if (cats.isEmpty) {
        final prods = await ApiService.getProducts();
        if (prods.isNotEmpty) {
          final set = <String>{};
          for (final p in prods) { if (p.category.isNotEmpty) set.add(p.category); }
          cats = set.toList()..sort();
        }
      }
      if (mounted) setState(() { _categories = cats; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = 'Failed to load categories'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: SwipifyTheme.white,
        elevation: 0,
        centerTitle: false,
        title: Text('Shop by Category', style: SwipifyTheme.heading2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SwipifyTheme.accentColor, strokeWidth: 2))
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _loadCategories)
              : _categories.isEmpty
                  ? Center(child: Text('No categories available', style: SwipifyTheme.bodySmall))
                  : RefreshIndicator(
                      color: SwipifyTheme.accentColor,
                      onRefresh: _loadCategories,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _categories.length,
                        itemBuilder: (_, i) => _CategorySection(category: _categories[i]),
                      ),
                    ),
    );
  }
}

class _CategorySection extends StatefulWidget {
  final String category;
  const _CategorySection({required this.category});
  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  List<ProductModel> _products = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _loadProducts(); }

  Future<void> _loadProducts() async {
    try {
      final p = await ApiService.getProductsByCategory(widget.category);
      if (mounted) setState(() { _products = p; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: SwipifyTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: SwipifyTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(children: [
            Text(widget.category, style: SwipifyTheme.productTitle.copyWith(fontSize: 16)),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CategoryDetailScreen(category: widget.category))),
              child: Text('See All ›', style: GoogleFonts.inter(color: SwipifyTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        if (_isLoading)
          const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: SwipifyTheme.accentColor, strokeWidth: 2)))
        else if (_products.isNotEmpty)
          SizedBox(
            height: 235, // Increased from 220 to avoid overflows
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _products.length > 6 ? 6 : _products.length,
              itemBuilder: (ctx, i) => Container(
                width: 155,
                margin: const EdgeInsets.only(right: 12),
                child: ProductCard(product: _products[i]),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No products found.', style: SwipifyTheme.bodySmall),
          ),
        const SizedBox(height: 4),
      ]),
    );
  }
}

class CategoryDetailScreen extends StatefulWidget {
  final String category;
  const CategoryDetailScreen({super.key, required this.category});
  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filtered = [];
  bool _isLoading = true;

  String _sortMode = 'Popular';
  String? _selectedRating;
  double? _maxPrice;
  final TextEditingController _searchCtrl = TextEditingController();

  static const _sortOptions = ['Popular', 'Newest', 'Price: Low to High', 'Price: High to Low', 'Best Rating'];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final p = await ApiService.getProductsByCategory(widget.category);
      if (mounted) { setState(() { _allProducts = p; _isLoading = false; }); _applyFilters(); }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var list = List<ProductModel>.from(_allProducts);
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) list = list.where((p) => p.name.toLowerCase().contains(q)).toList();
    if (_selectedRating == '4+') list = list.where((p) => p.rating >= 4).toList();
    if (_selectedRating == '3+') list = list.where((p) => p.rating >= 3).toList();
    if (_maxPrice != null) list = list.where((p) => p.price <= _maxPrice!).toList();
    switch (_sortMode) {
      case 'Price: Low to High': list.sort((a, b) => a.price.compareTo(b.price)); break;
      case 'Price: High to Low': list.sort((a, b) => b.price.compareTo(a.price)); break;
      case 'Best Rating': list.sort((a, b) => b.rating.compareTo(a.rating)); break;
      case 'Newest': list = list.reversed.toList(); break;
    }
    setState(() => _filtered = list);
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SwipifyTheme.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SwipifyTheme.borderColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Sort By', style: SwipifyTheme.productTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 12),
          ..._sortOptions.map((opt) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _sortMode == opt ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: _sortMode == opt ? SwipifyTheme.accentColor : SwipifyTheme.textMuted, size: 20,
            ),
            title: Text(opt, style: SwipifyTheme.bodySmall.copyWith(fontSize: 14, color: SwipifyTheme.textPrimary, fontWeight: _sortMode == opt ? FontWeight.w700 : FontWeight.w400)),
            onTap: () { setState(() => _sortMode = opt); _applyFilters(); Navigator.pop(context); },
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: SwipifyTheme.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: SwipifyTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.category, style: SwipifyTheme.heading2.copyWith(fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.sort_rounded, color: SwipifyTheme.primaryColor), onPressed: _showSortSheet),
          IconButton(icon: const Icon(Icons.tune_rounded, color: SwipifyTheme.primaryColor), onPressed: _showFilterSheet),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SwipifyTheme.accentColor, strokeWidth: 2))
          : Column(children: [
              Container(
                color: SwipifyTheme.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(color: SwipifyTheme.backgroundColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: SwipifyTheme.borderColor)),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => _applyFilters(),
                      style: SwipifyTheme.bodySmall.copyWith(color: SwipifyTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search in ${widget.category}...',
                        hintStyle: SwipifyTheme.bodySmall.copyWith(color: SwipifyTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: SwipifyTheme.textMuted, size: 18),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _FilterChip(label: _sortMode == 'Popular' ? 'Sort' : _sortMode, icon: Icons.sort_rounded, active: _sortMode != 'Popular', onTap: _showSortSheet),
                      const SizedBox(width: 8),
                      _FilterChip(label: _maxPrice != null ? '≤₱${_maxPrice!.toInt()}' : 'Price', icon: Icons.payments_outlined, active: _maxPrice != null, onTap: _showFilterSheet),
                      const SizedBox(width: 8),
                      _FilterChip(label: _selectedRating != null ? '★ $_selectedRating' : 'Rating', icon: Icons.star_outline_rounded, active: _selectedRating != null, onTap: _showFilterSheet),
                      const SizedBox(width: 8),
                      if (_selectedRating != null || _maxPrice != null || _sortMode != 'Popular')
                        _FilterChip(label: 'Clear', icon: Icons.close_rounded, active: false, onTap: () {
                          setState(() { _selectedRating = null; _maxPrice = null; _sortMode = 'Popular'; _searchCtrl.clear(); });
                          _applyFilters();
                        }),
                    ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_filtered.length} products found', style: SwipifyTheme.bodySmall),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.inventory_2_outlined, size: 64, color: SwipifyTheme.textMuted),
                        const SizedBox(height: 16),
                        Text('No products match your filters', style: SwipifyTheme.bodySmall),
                      ]))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.69, // Increased height slightly
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) => ProductCard(product: _filtered[i]),
                      ),
              ),
            ]),
    );
  }

  void _showFilterSheet() {
    double? tmpPrice = _maxPrice;
    String? tmpRating = _selectedRating;
    showModalBottomSheet(
      context: context,
      backgroundColor: SwipifyTheme.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setLocal) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SwipifyTheme.borderColor, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Filters', style: SwipifyTheme.productTitle.copyWith(fontSize: 18)),
          const SizedBox(height: 20),
          Text('Rating', style: SwipifyTheme.bodySmall.copyWith(color: SwipifyTheme.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: ['4+', '3+', 'All'].map((r) {
            final active = tmpRating == r || (r == 'All' && tmpRating == null);
            return GestureDetector(
              onTap: () => setLocal(() => tmpRating = r == 'All' ? null : r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? SwipifyTheme.accentColor : SwipifyTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? SwipifyTheme.accentColor : SwipifyTheme.borderColor),
                ),
                child: Text(r == 'All' ? 'All Ratings' : '★ $r',
                    style: SwipifyTheme.bodySmall.copyWith(fontWeight: FontWeight.w700, color: active ? Colors.white : SwipifyTheme.textSecondary)),
              ),
            );
          }).toList()),
          const SizedBox(height: 24),
          Text('Max Price', style: SwipifyTheme.bodySmall.copyWith(color: SwipifyTheme.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [500.0, 1000.0, 2500.0, 5000.0].map((val) {
            final active = tmpPrice == val;
            return GestureDetector(
              onTap: () => setLocal(() => tmpPrice = active ? null : val),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? SwipifyTheme.accentColor : SwipifyTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? SwipifyTheme.accentColor : SwipifyTheme.borderColor),
                ),
                child: Text('≤₱${val.toInt()}',
                    style: SwipifyTheme.bodySmall.copyWith(fontWeight: FontWeight.w700, color: active ? Colors.white : SwipifyTheme.textSecondary)),
              ),
            );
          }).toList()),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () { setLocal(() { tmpPrice = null; tmpRating = null; }); },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: SwipifyTheme.borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Reset', style: SwipifyTheme.bodySmall.copyWith(fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () { setState(() { _maxPrice = tmpPrice; _selectedRating = tmpRating; }); _applyFilters(); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(
                backgroundColor: SwipifyTheme.primaryColor, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Apply', style: SwipifyTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            )),
          ]),
        ]),
      )),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? SwipifyTheme.accentColor : SwipifyTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? SwipifyTheme.accentColor : SwipifyTheme.borderColor),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: active ? Colors.white : SwipifyTheme.textSecondary),
        const SizedBox(width: 6),
        Text(label, style: SwipifyTheme.bodySmall.copyWith(fontWeight: FontWeight.w700, color: active ? Colors.white : SwipifyTheme.textSecondary)),
      ]),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 56, color: SwipifyTheme.textMuted),
    const SizedBox(height: 12),
    Text(message, style: SwipifyTheme.bodySmall),
    const SizedBox(height: 20),
    ElevatedButton(onPressed: onRetry,
        style: ElevatedButton.styleFrom(backgroundColor: SwipifyTheme.accentColor, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text('Retry', style: SwipifyTheme.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
  ]));
}

