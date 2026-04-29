import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/screens/product_detail_screen.dart';

class BannerCarousel extends StatefulWidget {
  final List<ProductModel> products;
  final PageController controller;

  const BannerCarousel({
    super.key,
    required this.products,
    required this.controller,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  int _current = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final page = widget.controller.page?.round() ?? 0;
    if (page != _current) {
      setState(() => _current = page);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: SwipifyTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            PageView.builder(
              controller: widget.controller,
              itemCount: widget.products.length,
              itemBuilder: (context, index) {
                return _buildBannerItem(context, widget.products[index], index);
              },
            ),
            // Page Indicators
            Positioned(
              bottom: 20,
              right: 24,
              child: Row(
                children: List.generate(
                  widget.products.length,
                  (index) => _buildIndicator(index == _current),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildBannerItem(BuildContext context, ProductModel product, int index) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        double value = 1.0;
        if (widget.controller.position.haveDimensions) {
          try {
            value = widget.controller.page! - index;
          } catch (_) {
            value = (index - _current).toDouble();
          }
          value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
        } else {
          value = index == _current ? 1.0 : 0.7;
        }

        final double opacity = value.clamp(0.0, 1.0);
        final double slideTranslation = (1 - value) * 100;

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image with subtle scale parallax
              Transform.scale(
                scale: 1.0 + (1 - value) * 0.2,
                child: CachedNetworkImage(
                  imageUrl: product.primaryImage,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: SwipifyTheme.backgroundColor),
                  errorWidget: (context, url, err) => Container(
                    color: SwipifyTheme.backgroundColor,
                    child: const Icon(Icons.image_rounded, color: SwipifyTheme.textMuted, size: 48),
                  ),
                ),
              ),
              // Elegant Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              // Content with staggered animations
              Padding(
                padding: const EdgeInsets.all(24),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, slideTranslation),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _AnimatedBadge(isActive: index == _current),
                        const SizedBox(height: 12),
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '₱${product.price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                color: SwipifyTheme.accentColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const _ShopNowButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedBadge extends StatefulWidget {
  final bool isActive;
  const _AnimatedBadge({required this.isActive});

  @override
  State<_AnimatedBadge> createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<_AnimatedBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: SwipifyTheme.accentColor.withValues(alpha: 0.8 + (_ctrl.value * 0.2)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: SwipifyTheme.accentColor.withValues(alpha: 0.3 * _ctrl.value),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Text(
            'FEATURED DEAL',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        );
      },
    );
  }
}

class _ShopNowButton extends StatelessWidget {
  const _ShopNowButton();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Text(
        'Shop Now',
        style: GoogleFonts.inter(
          color: SwipifyTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
