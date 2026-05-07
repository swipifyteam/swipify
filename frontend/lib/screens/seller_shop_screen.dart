// screens/seller_shop_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/services/api_service.dart';
import 'package:swipify/widgets/product_card.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';

class SellerShopScreen extends StatefulWidget {
  final String sellerId;
  final String storeName;

  const SellerShopScreen({
    super.key, 
    required this.sellerId, 
    required this.storeName,
  });

  @override
  State<SellerShopScreen> createState() => _SellerShopScreenState();
}

class _SellerShopScreenState extends State<SellerShopScreen> {
  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  bool _isLoading = true;
  bool _isTogglingFollow = false;
  Map<String, dynamic>? _shopDetails;

  String _sortBy = 'Newest';
  String? _selectedCategory;
  final List<String> _categories = ['All', 'Clothing', 'Accessories', 'Shoes', 'Electronics'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final productsFuture = ApiService.getSellerProducts(widget.sellerId);
      final shopFuture = ApiService.getPublicShopInfo(widget.sellerId);
      
      final results = await Future.wait([productsFuture, shopFuture]);
      
      if (mounted) {
        setState(() {
          _allProducts = results[0] as List<ProductModel>;
          _shopDetails = results[1] as Map<String, dynamic>;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading shop: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    List<ProductModel> results = List.from(_allProducts);
    if (_selectedCategory != null && _selectedCategory != 'All') {
      results = results.where((p) => p.category == _selectedCategory).toList();
    }
    switch (_sortBy) {
      case 'Price: Low to High': results.sort((a, b) => a.price.compareTo(b.price)); break;
      case 'Price: High to Low': results.sort((a, b) => b.price.compareTo(a.price)); break;
      case 'Newest': results = results.reversed.toList(); break;
      case 'Popular':
        results.sort((a, b) {
          int countA = a.likeCount + (a.viewCount ~/ 10);
          int countB = b.likeCount + (b.viewCount ~/ 10);
          return countB.compareTo(countA);
        });
        break;
    }
    setState(() => _filteredProducts = results);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isFollowing = authProvider.user?.followedSellers.contains(widget.sellerId) ?? false;

    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(isFollowing, authProvider),
          _buildStoreStats(),
          _buildFilterSection(),
          _buildProductSectionHeader(),
          _buildProductGrid(),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isFollowing, AuthProvider authProvider) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      elevation: 0,
      backgroundColor: SwipifyTheme.primaryColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22), onPressed: () {}),
        IconButton(icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 24), onPressed: () {}),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [SwipifyTheme.primaryColor, Color(0xFF2C313B)],
                ),
                image: _shopDetails?['banner_url'] != null 
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(_shopDetails!['banner_url']),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.3), BlendMode.darken),
                    )
                  : null,
              ),
              child: _shopDetails?['banner_url'] == null 
                ? Opacity(
                    opacity: 0.15,
                    child: Center(
                      child: Icon(Icons.storefront_rounded, size: 200, color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  )
                : null,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.1),
                    SwipifyTheme.backgroundColor,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: SwipifyTheme.cardShadow,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: CachedNetworkImage(
                        imageUrl: _shopDetails?['logo_url'] ?? 'https://api.dicebear.com/7.x/initials/svg?seed=${widget.storeName}',
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => Container(color: SwipifyTheme.backgroundColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _shopDetails?['shop_name'] ?? widget.storeName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (_shopDetails?['description'] != null && _shopDetails!['description'].isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _shopDetails!['description'],
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: SwipifyTheme.starColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${_shopDetails?['rating'] ?? '5.0'} (${_shopDetails?['review_count'] ?? '0'} reviews)',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_shopDetails?['vacation_mode'] == true)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.orange.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Text(
                      'SHOP ON VACATION 🌴',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 30,
              right: 20,
              child: _buildFollowButton(isFollowing, authProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(bool isFollowing, AuthProvider authProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isTogglingFollow ? null : () async {
          setState(() => _isTogglingFollow = true);
          final bool wasFollowing = authProvider.user?.followedSellers.contains(widget.sellerId) ?? false;
          await authProvider.toggleFollowSeller(widget.sellerId);
          if (mounted) {
            setState(() {
              _isTogglingFollow = false;
              if (_shopDetails != null) {
                int currentFollowers = _shopDetails!['follower_count'] ?? 0;
                if (wasFollowing) {
                  _shopDetails!['follower_count'] = (currentFollowers > 0) ? currentFollowers - 1 : 0;
                } else {
                  _shopDetails!['follower_count'] = currentFollowers + 1;
                }
              }
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isFollowing ? Colors.white.withValues(alpha: 0.15) : SwipifyTheme.accentColor,
            borderRadius: BorderRadius.circular(16),
            border: isFollowing ? Border.all(color: Colors.white, width: 1.5) : null,
          ),
          child: _isTogglingFollow 
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
              ),
        ),
      ),
    );
  }

  Widget _buildStoreStats() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: SwipifyTheme.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: SwipifyTheme.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('Products', _allProducts.length.toString()),
            _statItem('Followers', _getFollowerCount()),
            _statItem('Rating', '4.9'),
            _statItem('Joined', '2y ago'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: SwipifyTheme.productTitle.copyWith(fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: SwipifyTheme.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _getFollowerCount() {
    int count = _shopDetails?['follower_count'] ?? 0;
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Widget _buildFilterSection() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        margin: const EdgeInsets.only(top: 10),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = (_selectedCategory ?? 'All') == category;
            return Padding(
              padding: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = category == 'All' ? null : category;
                    _applyFilters();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? SwipifyTheme.accentColor : SwipifyTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? SwipifyTheme.accentColor : SwipifyTheme.borderColor),
                    boxShadow: isSelected ? SwipifyTheme.glassShadow : null,
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : SwipifyTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductSectionHeader() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Text('${_filteredProducts.length} Results', style: SwipifyTheme.heading2.copyWith(fontSize: 18)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: SwipifyTheme.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SwipifyTheme.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  icon: const Icon(Icons.expand_more_rounded, size: 20, color: SwipifyTheme.textSecondary),
                  elevation: 4,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: SwipifyTheme.textPrimary),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() { _sortBy = newValue; _applyFilters(); });
                    }
                  },
                  items: <String>['Newest', 'Price: Low to High', 'Price: High to Low', 'Popular']
                    .map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: SwipifyTheme.accentColor)));
    }
    if (_filteredProducts.isEmpty) {
      return SliverFillRemaining(
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: SwipifyTheme.textMuted),
          const SizedBox(height: 16),
          Text('No products found.', style: SwipifyTheme.bodySmall),
        ])),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.72, mainAxisSpacing: 16, crossAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCard(product: _filteredProducts[index]),
          childCount: _filteredProducts.length,
        ),
      ),
    );
  }
}
