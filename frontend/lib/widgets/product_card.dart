import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/screens/product_detail_screen.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SwipifyTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: SwipifyTheme.cardShadow,
      ),
      child: InkWell(
        onTap: onTap ?? () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image — takes exactly 60% of available height
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: product.primaryImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: SwipifyTheme.backgroundColor),
                      errorWidget: (context, url, error) => Container(
                        color: SwipifyTheme.backgroundColor,
                        child: const Icon(Icons.image_rounded, color: SwipifyTheme.borderColor, size: 40),
                      ),
                    ),
                    // Video indicator
                    if (product.videoCount > 0)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    // Category badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: SwipifyTheme.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          style: SwipifyTheme.badge,
                        ),
                      ),
                    ),
                    // Wishlist button
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        height: 28,
                        width: 28,
                        decoration: BoxDecoration(
                          color: SwipifyTheme.white.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite_outline_rounded, size: 14, color: SwipifyTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text content — takes remaining 40%
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Product name — clamps to 2 lines
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SwipifyTheme.productTitle.copyWith(fontSize: 12, height: 1.2),
                    ),
                    const Spacer(),
                    // Price + rating
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '₱${product.price.toStringAsFixed(0)}',
                            style: SwipifyTheme.productPrice.copyWith(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded, color: SwipifyTheme.starColor, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: SwipifyTheme.bodySmall.copyWith(
                            color: SwipifyTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Shop name
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 11, color: SwipifyTheme.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            product.shopName.isNotEmpty ? product.shopName : 'Official Store',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwipifyTheme.bodySmall.copyWith(fontSize: 10),
                          ),
                        ),
                      ],
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
}
