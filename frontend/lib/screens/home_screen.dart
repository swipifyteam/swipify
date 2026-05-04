// screens/home_screen.dart
// Redesign — Apple + Shopify-inspired minimalist luxury aesthetic.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:swipify/core/theme.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/models/seller_voucher_model.dart';
import 'package:swipify/features/cart/service/cart_provider.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/features/navigation/categories_screen.dart';
import 'package:swipify/services/api_service.dart';
import 'package:swipify/services/products_cache.dart';
import 'package:swipify/features/cart/screen/cart_screen.dart';
import 'package:swipify/features/navigation/screen/notification_screen.dart';
import 'package:swipify/screens/product_detail_screen.dart';
import 'package:swipify/features/navigation/service/notification_provider.dart';
import 'package:swipify/widgets/product_card.dart';
import 'package:swipify/widgets/banner_carousel.dart';
import 'package:swipify/widgets/category_chip.dart';
import 'package:swipify/widgets/voucher_card.dart';
import 'package:swipify/screens/chat_list_screen.dart';
import 'package:swipify/services/chat_service.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<ProductModel> _products = [];
  List<String> _categories = [];
  List<SellerVoucherModel> _vouchers = [];
  List<ProductModel> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  void Function()? _cacheListener;

  final PageController _bannerCtrl = PageController();
  final PageController _carouselCtrl = PageController(viewportFraction: 0.85);
  Timer? _bannerTimer;
  Timer? _carouselTimer;
  int _bannerIndex = 0;
  int _carouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _products = ProductsCache.products.value;
    _cacheListener = () {
      if (mounted) {
        setState(() {
          _products = ProductsCache.products.value;
        });
        _startBannerTimer(); // Refresh banner timer with new products
      }
    };
    ProductsCache.products.addListener(_cacheListener!);
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      context.read<CartProvider>().loadCart(uid);
    });
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    final featured = _products.where((p) => p.rating >= 4.5).toList();
    if (featured.length < 2) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _bannerIndex = (_bannerIndex + 1) % featured.length;
      _bannerCtrl.animateToPage(_bannerIndex,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_products.length < 2) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _carouselIndex = (_carouselIndex + 1) % _products.length;
      if (_carouselCtrl.hasClients) {
        _carouselCtrl.animateToPage(
          _carouselIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerCtrl.dispose();
    _carouselCtrl.dispose();
    _bannerTimer?.cancel();
    _carouselTimer?.cancel();
    if (_cacheListener != null) ProductsCache.products.removeListener(_cacheListener!);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final hasData = _products.isNotEmpty || _categories.isNotEmpty;
    if (!hasData) setState(() { _isLoading = true; _error = null; });

    try {
      final results = await Future.wait([
        ApiService.getProducts(),
        ApiService.getCategories(),
        ApiService.getVouchers(),
      ]);

      if (mounted) {
        final products = results[0] as List<ProductModel>;
        ProductsCache.set(products); // triggers _cacheListener → rebuilds

        setState(() {
          _categories = results[1] as List<String>;
          _vouchers = results[2] as List<SellerVoucherModel>;
          _isLoading = false;
          _error = null;
        });
        _startCarouselTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearch(String val) {
    if (val.trim().isEmpty) {
      setState(() { _isSearching = false; _searchResults = []; });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchResults = _products.where((p) => 
        p.name.toLowerCase().contains(val.toLowerCase()) || 
        p.category.toLowerCase().contains(val.toLowerCase())
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  color: SwipifyTheme.accentColor,
                  child: _isSearching 
                    ? _SearchResultsView(results: _searchResults, isLoading: false, query: _searchController.text)
                    : _buildHomeContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          // Swipify Logo Section — use Flexible so it shrinks on small screens
          Flexible(
            flex: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_bag_rounded, size: 22, color: SwipifyTheme.accentColor),
                const SizedBox(width: 4),
                Text(
                  'Swipify',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: SwipifyTheme.primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Search bar takes all remaining space
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: SwipifyTheme.glassShadow,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: SwipifyTheme.bodySmall.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  hintStyle: SwipifyTheme.bodySmall.copyWith(color: SwipifyTheme.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: SwipifyTheme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          // Chat button — bounded width
          SizedBox(
            width: 40,
            height: 40,
            child: const _ChatButton(),
          ),
          // Notification bell — bounded width to prevent overflow
          SizedBox(
            width: 40,
            height: 40,
            child: const _NotificationBell(),
          ),
          // Cart button — bounded width
          SizedBox(
            width: 40,
            height: 40,
            child: _CartButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: SwipifyTheme.accentColor));
    }
    if (_error != null && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text('Failed to load data', style: SwipifyTheme.productTitle),
            TextButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: SwipifyTheme.textMuted),
            const SizedBox(height: 16),
            Text('No products available right now', style: SwipifyTheme.productTitle),
          ],
        ),
      );
    }

    final featured = _products.where((p) => p.rating >= 4.5).take(5).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Auto-swipe product carousel (right after header) ──────────
              _ProductCarouselStrip(
                products: _products,
                controller: _carouselCtrl,
                currentIndex: _carouselIndex,
                onPageChanged: (i) => setState(() => _carouselIndex = i),
              ),
              // ── Featured banner ───────────────────────────────────────────
              if (featured.isNotEmpty)
                BannerCarousel(products: featured, controller: _bannerCtrl),
              _CategoriesRow(categories: _categories),
              if (_vouchers.isNotEmpty) _VoucherStrip(vouchers: _vouchers),
              _SectionHeader(label: 'Special Deals', onSeeAll: () {}),
              _FlashDealsSection(products: _products.take(6).toList()),
              _SectionHeader(label: 'Recommended for You'),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => ProductCard(product: _products[i]),
              childCount: _products.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Auto-swipe product carousel strip ───────────────────────────────────────
class _ProductCarouselStrip extends StatelessWidget {
  final List<ProductModel> products;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _ProductCarouselStrip({
    required this.products,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: controller,
            itemCount: products.length,
            onPageChanged: onPageChanged,
            itemBuilder: (ctx, i) {
              final product = products[i];
              final isActive = currentIndex == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: isActive ? 0 : 12,
                ),
                child: InkWell(
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isActive ? SwipifyTheme.cardShadow : SwipifyTheme.glassShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Product image
                          product.primaryImage.isNotEmpty
                              ? Image.network(
                                  product.primaryImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: SwipifyTheme.backgroundColor,
                                    child: const Icon(Icons.image_rounded, color: SwipifyTheme.borderColor, size: 40),
                                  ),
                                )
                              : Container(color: SwipifyTheme.backgroundColor),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                          // Product info at bottom
                          Positioned(
                            bottom: 12,
                            left: 14,
                            right: 14,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '₱${product.price.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(
                                          color: SwipifyTheme.accentColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: SwipifyTheme.accentColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Buy',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Page dots
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            products.length.clamp(0, 8),
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 5,
              width: currentIndex == i ? 20 : 5,
              decoration: BoxDecoration(
                color: currentIndex == i ? SwipifyTheme.accentColor : SwipifyTheme.borderColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(builder: (ctx, cart, _) => Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined, color: SwipifyTheme.primaryColor, size: 22),
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CartScreen())),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        if (cart.itemCount > 0) Positioned(
          top: 4, right: 4,
          child: Container(
            width: 14, height: 14,
            decoration: const BoxDecoration(color: SwipifyTheme.accentColor, shape: BoxShape.circle),
            child: Center(child: Text('${cart.itemCount}', style: SwipifyTheme.badge.copyWith(color: Colors.white, fontSize: 8))),
          ),
        ),
      ],
    ));
  }
}

class _CategoriesRow extends StatelessWidget {
  final List<String> categories;
  const _CategoriesRow({required this.categories});

  static const _icons = <String, IconData>{
    'electronics': Icons.devices_rounded,
    'clothing': Icons.checkroom_rounded,
    'footwear': Icons.do_not_step_rounded,
    'accessories': Icons.watch_rounded,
    'home & living': Icons.chair_rounded,
    'beauty': Icons.face_retouching_natural,
    'sports': Icons.sports_basketball_rounded,
    'food': Icons.restaurant_rounded,
    'books': Icons.menu_book_rounded,
    'toys': Icons.toys_rounded,
  };

  static const _colors = [
    Color(0xFFFFEDD5), Color(0xFFEDE9FE), Color(0xFFDCFCE7),
    Color(0xFFDBEAFE), Color(0xFFFCE7F3), Color(0xFFFEF3C7),
  ];
  static const _iconColors = [
    SwipifyTheme.accentColor, Color(0xFF7C5CBF), Color(0xFF16A34A),
    Color(0xFF2563EB), Color(0xFFDB2777), Color(0xFFD97706),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Categories', onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()
        )
        )
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              return CategoryChip(
                category: cat,
                icon: _icons[cat.toLowerCase()] ?? Icons.category_rounded,
                backgroundColor: _colors[i % _colors.length],
                iconColor: _iconColors[i % _iconColors.length],
                onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CategoryDetailScreen(category: cat))),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FlashDealsSection extends StatelessWidget {
  final List<ProductModel> products;
  const _FlashDealsSection({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: SwipifyTheme.accentColor, borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('FLASH SALE', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ]),
                ),
                const Spacer(),
                Text('Ends in 02:45:12', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Cards in a horizontal scroller, height computed dynamically via LayoutBuilder
          LayoutBuilder(
            builder: (ctx, constraints) {
              // Card width = 160, aspect = 0.68 → height ≈ 235
              const double cardWidth = 160;
              const double cardHeight = cardWidth / 0.68;
              return SizedBox(
                height: cardHeight + 20, // +20 for bottom padding
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) => SizedBox(
                    width: cardWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ProductCard(product: products[i]),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VoucherStrip extends StatelessWidget {
  final List<SellerVoucherModel> vouchers;
  const _VoucherStrip({required this.vouchers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Coupons for You'),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: vouchers.length,
            itemBuilder: (ctx, i) => VoucherCard(
              voucher: vouchers[i],
              width: 280,
              margin: const EdgeInsets.only(right: 16),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.label, this.onSeeAll});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 12, 12),
    child: Row(children: [
      Expanded(child: Text(label, style: SwipifyTheme.heading2.copyWith(fontSize: 18))),
      if (onSeeAll != null) TextButton(
        onPressed: onSeeAll,
        child: Text('View Details', style: GoogleFonts.inter(color: SwipifyTheme.accentColor, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

class _SearchResultsView extends StatelessWidget {
  final List<ProductModel> results;
  final bool isLoading;
  final String query;
  const _SearchResultsView({required this.results, required this.isLoading, required this.query});

  @override
  Widget build(BuildContext context) {
    if (isLoading && results.isEmpty) return const Center(child: CircularProgressIndicator(color: SwipifyTheme.accentColor, strokeWidth: 2));
    if (results.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off_rounded, size: 64, color: SwipifyTheme.textMuted),
        const SizedBox(height: 16),
        Text('No results for "$query"', style: SwipifyTheme.productTitle.copyWith(color: SwipifyTheme.textSecondary)),
      ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72, mainAxisSpacing: 16, crossAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (ctx, i) => ProductCard(product: results[i]),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();
  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    context.read<NotificationProvider>().init(uid);
  }
  @override
  Widget build(BuildContext context) => Consumer<NotificationProvider>(builder: (ctx, provider, _) {
    final unread = provider.unreadCount;
    return InkWell(
      onTap: () async {
        await Navigator.push(ctx, MaterialPageRoute(builder: (_) => const NotificationScreen()));
        provider.loadNotifications();
      },
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          const Icon(Icons.notifications_outlined, color: SwipifyTheme.primaryColor, size: 22),
          if (unread > 0) Positioned(
            top: 6, right: 6,
            child: Container(
              width: 12, height: 12,
              decoration: const BoxDecoration(color: SwipifyTheme.accentColor, shape: BoxShape.circle),
              child: Center(child: Text('${unread > 9 ? "9+" : unread}', style: SwipifyTheme.badge.copyWith(color: Colors.white, fontSize: 7))),
            ),
          ),
        ]),
      ),
    );
  });
}

class _ChatButton extends StatefulWidget {
  const _ChatButton();
  @override
  State<_ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<_ChatButton> {
  int _unreadCount = 0;
  StreamSubscription? _chatSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (uid != null) {
      _chatSub?.cancel();
      _chatSub = ChatService().getUserChats(uid).listen((chats) {
        int unread = 0;
        for (var chat in chats) {
          unread += (chat.unreadCount[uid] ?? 0);
        }
        if (mounted) {
          setState(() => _unreadCount = unread);
        }
      });
    }
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final uid = context.read<AuthProvider>().user?.uid;
        if (uid == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to chat')));
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
      },
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: SwipifyTheme.primaryColor, size: 22),
          if (_unreadCount > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: SwipifyTheme.accentColor, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    '${_unreadCount > 9 ? "9+" : _unreadCount}',
                    style: SwipifyTheme.badge.copyWith(color: Colors.white, fontSize: 7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

