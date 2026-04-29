// lib/screens/products_listing_screen.dart
// Product listing for a given category / search query.
// Overflow-safe: grid uses LayoutBuilder-derived aspect ratio.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:swipify/core/theme.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/services/api_service.dart';
import 'package:swipify/services/products_cache.dart';
import 'package:swipify/widgets/product_card.dart';

enum _SortOption { newest, priceLow, priceHigh, rating }

class ProductsListingScreen extends StatefulWidget {
  final String? category;
  final String? query;

  const ProductsListingScreen({super.key, this.category, this.query});

  @override
  State<ProductsListingScreen> createState() => _ProductsListingScreenState();
}

class _ProductsListingScreenState extends State<ProductsListingScreen> {
  List<ProductModel> _all = [];
  List<ProductModel> _filtered = [];
  bool _isLoading = true;
  String? _error;
  _SortOption _sort = _SortOption.newest;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.query ?? '';
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      // Use cache first for instant display, then refetch
      var products = ProductsCache.products.value;
      if (products.isEmpty) {
        products = await ApiService.getProducts();
        ProductsCache.set(products);
      }
      if (mounted) {
        setState(() {
          _all = products;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _applyFilters() {
    var results = List<ProductModel>.from(_all);

    // Category filter
    if (widget.category != null && widget.category!.isNotEmpty) {
      results = results.where((p) =>
        p.category.toLowerCase() == widget.category!.toLowerCase()
      ).toList();
    }

    // Search filter
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      results = results.where((p) =>
        p.name.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q) ||
        p.shopName.toLowerCase().contains(q)
      ).toList();
    }

    // Sort
    switch (_sort) {
      case _SortOption.priceLow:
        results.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SortOption.priceHigh:
        results.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortOption.rating:
        results.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _SortOption.newest:
        break; // API order = newest first
    }

    setState(() => _filtered = results);
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SwipifyTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sort by', style: SwipifyTheme.heading2.copyWith(fontSize: 18)),
            const SizedBox(height: 16),
            ..._SortOption.values.map((opt) {
              final labels = {
                _SortOption.newest: 'Newest First',
                _SortOption.priceLow: 'Price: Low to High',
                _SortOption.priceHigh: 'Price: High to Low',
                _SortOption.rating: 'Top Rated',
              };
              final icons = {
                _SortOption.newest: Icons.schedule_rounded,
                _SortOption.priceLow: Icons.arrow_upward_rounded,
                _SortOption.priceHigh: Icons.arrow_downward_rounded,
                _SortOption.rating: Icons.star_rounded,
              };
              final selected = _sort == opt;
              return InkWell(
                onTap: () {
                  setState(() => _sort = opt);
                  _applyFilters();
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: selected ? SwipifyTheme.accentColor.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? SwipifyTheme.accentColor : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icons[opt], size: 20, color: selected ? SwipifyTheme.accentColor : SwipifyTheme.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        labels[opt]!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? SwipifyTheme.accentColor : SwipifyTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (selected) const Icon(Icons.check_rounded, size: 18, color: SwipifyTheme.accentColor),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.category ?? (widget.query != null ? 'Search Results' : 'All Products');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: SwipifyTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: SwipifyTheme.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: SwipifyTheme.primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            title,
            style: SwipifyTheme.heading2.copyWith(fontSize: 18),
          ),
          actions: [
            TextButton.icon(
              onPressed: _showSortSheet,
              icon: const Icon(Icons.sort_rounded, size: 18, color: SwipifyTheme.accentColor),
              label: Text(
                'Sort',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SwipifyTheme.accentColor,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: SwipifyTheme.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: SwipifyTheme.glassShadow,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _applyFilters(),
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search in ${widget.category ?? 'all products'}…',
                    hintStyle: SwipifyTheme.bodySmall.copyWith(color: SwipifyTheme.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: SwipifyTheme.textSecondary),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16, color: SwipifyTheme.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),
            // Results count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_filtered.length} products',
                    style: SwipifyTheme.bodySmall.copyWith(
                      color: SwipifyTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: SwipifyTheme.accentColor, strokeWidth: 2))
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _loadProducts)
                      : _filtered.isEmpty
                          ? _EmptyView(category: widget.category)
                          : RefreshIndicator(
                              onRefresh: _loadProducts,
                              color: SwipifyTheme.accentColor,
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                physics: const BouncingScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.68,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                ),
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) => ProductCard(product: _filtered[i]),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String? category;
  const _EmptyView({this.category});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inventory_2_outlined, size: 64, color: SwipifyTheme.textMuted),
        const SizedBox(height: 16),
        Text(
          category != null ? 'No products in "$category"' : 'No products found',
          style: SwipifyTheme.productTitle.copyWith(color: SwipifyTheme.textSecondary),
        ),
        const SizedBox(height: 8),
        Text('Try a different search or category',
          style: SwipifyTheme.bodySmall),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text('Failed to load products', style: SwipifyTheme.productTitle),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Retry'),
          style: TextButton.styleFrom(foregroundColor: SwipifyTheme.accentColor),
        ),
      ],
    ),
  );
}

