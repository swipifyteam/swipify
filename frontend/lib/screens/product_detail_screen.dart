// screens/product_detail_screen.dart
// Redesign — Apple Store + Shopify-inspired luxury aesthetic.
// Clean hierarchy, spacious layout, and conversion-optimized bottom bar.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/features/cart/service/cart_provider.dart';
import 'package:swipify/features/cart/model/cart_item_model.dart';
import 'package:swipify/features/auth/service/auth_provider.dart';
import 'package:swipify/services/review_service.dart';
import 'package:swipify/screens/seller_shop_screen.dart';
import 'package:swipify/screens/checkout_screen.dart';
import 'package:swipify/services/chat_service.dart';
import 'package:swipify/screens/chat_screen.dart';
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  String _selectedColor = 'Default';
  bool _addingToCart = false;
  late Future<List<Map<String, dynamic>>> _futureReviews;
  bool _descExpanded = false;
  final PageController _imgCtrl = PageController();
  int _currentImg = 0;

  @override
  void initState() {
    super.initState();
    _futureReviews = ReviewService.getReviews(widget.product.id);
    if (widget.product.colors.isNotEmpty) _selectedColor = widget.product.colors.first;
  }

  // ─── UI Actions ─────────────────────────────────────────────────────────────

  Future<void> _onAddToCart() async {
    setState(() => _addingToCart = true);
    try {
      final uid = context.read<AuthProvider>().user?.uid;
      await context.read<CartProvider>().addToCart(uid, widget.product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.product.name} added to cart 🛒'),
            backgroundColor: SwipifyTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add to cart')));
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  Future<void> _onBuyNow() async {
    setState(() => _addingToCart = true);
    try {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid == null) throw Exception("Please login first");

      // Build a CartItemModel from this product so the checkout screen can process it
      final cartItem = CartItemModel(
        productId: widget.product.id,
        quantity: _quantity,
        product: widget.product,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CheckoutScreen(),
            settings: RouteSettings(arguments: [cartItem]),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Buy Now failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  void _showSelectionSheet({required bool isBuyNow}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(imageUrl: widget.product.primaryImage, width: 90, height: 90, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₱${(widget.product.price * _quantity).toStringAsFixed(2)}', 
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: SwipifyTheme.accentColor)),
                      Text('In Stock: ${widget.product.stock}', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 13)),
                    ],
                  )),
                ],
              ),
              const SizedBox(height: 32),
              Text('Variation', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: ['Red', 'Blue', 'Charcoal'].map((varT) {
                final sel = _selectedColor == varT;
                return GestureDetector(
                  onTap: () => setS(() => _selectedColor = varT),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? SwipifyTheme.accentColor.withValues(alpha: 0.1) : SwipifyTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? SwipifyTheme.accentColor : Colors.transparent),
                    ),
                    child: Text(varT, style: GoogleFonts.inter(color: sel ? SwipifyTheme.accentColor : SwipifyTheme.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Quantity', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                  Row(children: [
                    _QtyBtn(icon: Icons.remove, onTap: _quantity > 1 ? () => setS(() => _quantity--) : null),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('$_quantity', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    _QtyBtn(icon: Icons.add, onTap: () => setS(() => _quantity++)),
                  ]),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); isBuyNow ? _onBuyNow() : _onAddToCart(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwipifyTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(isBuyNow ? 'Confirm Purchase' : 'Add to Bag', 
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      backgroundColor: SwipifyTheme.backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Hero Product Image Section
              SliverToBoxAdapter(child: _buildHeroSection(p)),

              // 2. Product Info Section
              SliverToBoxAdapter(child: _buildProductInfo(p)),

              // 3. Shipping & Info
              SliverToBoxAdapter(child: _buildShippingInfo()),

              // 4. Seller Section
              SliverToBoxAdapter(child: _buildSellerSection(p)),

              // 5. Description
              SliverToBoxAdapter(child: _buildDescription(p)),

              // 6. Reviews
              SliverToBoxAdapter(child: _buildReviewsSection()),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          // Sticky Top Buttons
          Positioned(top: MediaQuery.of(context).padding.top + 10, left: 16, right: 16, child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FloatingCircleBtn(icon: Icons.chevron_left, onTap: () => Navigator.pop(context)),
              Row(children: [
                _FloatingCircleBtn(icon: Icons.share_outlined, onTap: () {}),
              ]),
            ],
          )),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Component Builders ─────────────────────────────────────────────────────

  Widget _buildHeroSection(ProductModel p) {
    final images = p.images.isNotEmpty ? p.images : [p.primaryImage];
    return Container(
      height: 420,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            PageView.builder(
              controller: _imgCtrl,
              itemCount: images.length,
              onPageChanged: (v) => setState(() => _currentImg = v),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _showZoomedImage(images[i]),
                child: CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover),
              ),
            ),
            Positioned(bottom: 24, left: 0, right: 0, child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentImg == i ? 24 : 8, height: 8,
                decoration: BoxDecoration(
                  color: _currentImg == i ? SwipifyTheme.primaryColor : SwipifyTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              )),
            )),
          ],
        ),
      ),
    );
  }

  void _showZoomedImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Stack(
        children: [
          InteractiveViewer(
            child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
          ),
          Positioned(top: 40, right: 20, child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(ctx),
          )),
        ],
      ),
    );
  }

  Widget _buildProductInfo(ProductModel p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: SwipifyTheme.cardColor, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
            child: Text('🟢 In Stock', style: GoogleFonts.inter(color: const Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          Row(children: [
            const Icon(Icons.star_rounded, color: SwipifyTheme.starColor, size: 18),
            Text(' ${p.rating.toStringAsFixed(1)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: SwipifyTheme.textPrimary)),
            Text(' (128 reviews)', style: GoogleFonts.inter(fontSize: 12, color: SwipifyTheme.textSecondary)),
          ]),
        ]),
        const SizedBox(height: 16),
        Text(p.name, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: SwipifyTheme.textPrimary, height: 1.2)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(
            child: Text('₱${p.price.toStringAsFixed(2)}', 
              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: SwipifyTheme.accentColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text('₱${(p.price * 1.25).toStringAsFixed(0)}', 
            style: GoogleFonts.inter(fontSize: 16, decoration: TextDecoration.lineThrough, color: SwipifyTheme.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _buildSellerSection(ProductModel p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: SwipifyTheme.cardColor, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: SwipifyTheme.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: SwipifyTheme.borderColor, width: 2),
            ),
            child: const Icon(Icons.storefront_rounded, color: SwipifyTheme.accentColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.shopName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: SwipifyTheme.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.star_rounded, color: SwipifyTheme.starColor, size: 14),
                  Text(' 4.9', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: SwipifyTheme.textPrimary)),
                  const SizedBox(width: 8),
                  Text('· 12.5k Followers', style: GoogleFonts.inter(fontSize: 12, color: SwipifyTheme.textSecondary)),
                ]),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellerShopScreen(sellerId: p.shopId, storeName: p.shopName))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: SwipifyTheme.accentColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('Visit Store', style: GoogleFonts.inter(color: SwipifyTheme.accentColor, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Expanded(child: _InfoTile(icon: Icons.local_shipping_outlined, label: 'Free Delivery', sub: '3-5 days')),
        const SizedBox(width: 12),
        Expanded(child: _InfoTile(icon: Icons.restart_alt_rounded, label: '7 Days Return', sub: 'Hassle-free')),
        const SizedBox(width: 12),
        Expanded(child: _InfoTile(icon: Icons.verified_user_outlined, label: 'Secured', sub: '100% Genuine')),
      ]),
    );
  }

  Widget _buildDescription(ProductModel p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: SwipifyTheme.cardColor, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Product Description', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: SwipifyTheme.textPrimary)),
        const SizedBox(height: 12),
        Text(p.description,
          maxLines: _descExpanded ? 100 : 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 14, color: SwipifyTheme.textSecondary, height: 1.6)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _descExpanded = !_descExpanded),
          child: Text(_descExpanded ? 'Read Less' : 'Read More', 
            style: GoogleFonts.inter(color: SwipifyTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: SwipifyTheme.cardColor, borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Customer Reviews', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: SwipifyTheme.textPrimary))),
          Text('View All', style: GoogleFonts.inter(color: SwipifyTheme.accentColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Column(children: [
            Text('4.8', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, color: SwipifyTheme.textPrimary)),
            Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, color: SwipifyTheme.starColor, size: 16))),
            const SizedBox(height: 4),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureReviews,
              builder: (context, snap) {
                final count = snap.data?.length ?? 128;
                return Text('$count reviews', style: GoogleFonts.inter(color: SwipifyTheme.textSecondary, fontSize: 11));
              },
            ),
          ]),
          const SizedBox(width: 32),
          Expanded(child: Column(children: [
            _StarBar(stars: 5, pct: 0.85),
            _StarBar(stars: 4, pct: 0.10),
            _StarBar(stars: 3, pct: 0.03),
            _StarBar(stars: 2, pct: 0.01),
            _StarBar(stars: 1, pct: 0.01),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: Row(
        children: [
          _BottomActionBtn(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Chat',
            onTap: () async {
              final uid = context.read<AuthProvider>().user?.uid;
              if (uid == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please login to chat')),
                );
                return;
              }
              
              if (uid == widget.product.shopId || uid == widget.product.sellerId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You cannot chat with yourself')),
                );
                return;
              }

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final sellerId = widget.product.sellerId.isNotEmpty ? widget.product.sellerId : widget.product.shopId;
                final chatId = await ChatService().createOrGetChat(
                  buyerId: uid,
                  sellerId: sellerId,
                  productId: widget.product.id,
                  productName: widget.product.name,
                  productImage: widget.product.primaryImage,
                );

                // Auto-send initial message if chat is new
                final messages = await ChatService().getMessagesOnce(chatId);
                if (messages.isEmpty && mounted) {
                  final senderName = context.read<AuthProvider>().user?.displayName ?? 'User';
                  await ChatService().sendMessage(
                    chatId: chatId,
                    senderId: uid,
                    receiverId: sellerId,
                    message: "Hi, I'm interested in this product: ${widget.product.name}",
                    type: 'text',
                    senderName: senderName,
                  );
                }

                if (mounted) {
                  Navigator.pop(context); // hide loading
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chatId,
                        otherUserId: sellerId,
                        otherUserName: widget.product.shopName,
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // hide loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to open chat: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 20),
          _BottomActionBtn(
            icon: Icons.storefront_outlined, 
            label: 'Store', 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SellerShopScreen(sellerId: widget.product.shopId, storeName: widget.product.shopName))),
          ),
          const SizedBox(width: 24),
          Expanded(child: GestureDetector(
            onTap: _addingToCart ? null : () => _showSelectionSheet(isBuyNow: false),
            child: Container(
              height: 52,
              decoration: BoxDecoration(color: SwipifyTheme.backgroundColor, borderRadius: BorderRadius.circular(16)),
              child: Center(child: _addingToCart
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Add to Bag', style: GoogleFonts.inter(color: SwipifyTheme.primaryColor, fontWeight: FontWeight.w700))),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: _addingToCart ? null : () => _showSelectionSheet(isBuyNow: true),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [SwipifyTheme.primaryColor, Color(0xFF334155)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: SwipifyTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
                ],
              ),
              child: Center(child: Text('Buy Now', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
            ),
          )),
        ],
      ),
    );
  }
}

// ─── Sub-Widgets ─────────────────────────────────────────────────────────────

class _FloatingCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  const _FloatingCircleBtn({required this.icon, required this.onTap, this.iconColor});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, 
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
      child: Icon(icon, color: iconColor ?? SwipifyTheme.primaryColor, size: 24),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  const _InfoTile({required this.icon, required this.label, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: SwipifyTheme.cardColor, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: SwipifyTheme.accentColor, size: 20),
      const SizedBox(height: 8),
      Text(
        label, 
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: SwipifyTheme.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        sub, 
        style: GoogleFonts.inter(fontSize: 10, color: SwipifyTheme.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ]),
  );
}

class _StarBar extends StatelessWidget {
  final int stars;
  final double pct;
  const _StarBar({required this.stars, required this.pct});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text('$stars', style: GoogleFonts.inter(fontSize: 11, color: SwipifyTheme.textSecondary, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(value: pct, backgroundColor: SwipifyTheme.backgroundColor, valueColor: const AlwaysStoppedAnimation(SwipifyTheme.starColor), minHeight: 6),
      )),
    ]),
  );
}

class _BottomActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: SwipifyTheme.textSecondary, size: 22),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: SwipifyTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: SwipifyTheme.backgroundColor, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 18, color: onTap == null ? SwipifyTheme.textMuted : SwipifyTheme.primaryColor),
    ),
  );
}


