// lib/features/cart/model/cart_item_model.dart
// Cart Item Model for the Swipify ecommerce platform.
// Represents a product + its quantity in a user's persistent cart.

import 'package:swipify/features/products/model/product_model.dart';

class CartItemModel {
  final String productId;
  final int quantity;
  final ProductModel? product; // 🚨 PART 1 & 2 FIX: ENRICHED PRODUCT DATA 🚨
  
  CartItemModel({
    required this.productId,
    required this.quantity,
    this.product,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    // 🚨 ENRICHMENT CHECK 🚨
    // backend sends full product data as part of the item JSON.
    // Ensure we parse it into ProductModel if present.
    ProductModel? enrichedProduct;
    if (json['product'] != null) {
       enrichedProduct = ProductModel.fromJson(json['product'] as Map<String, dynamic>);
    }

    return CartItemModel(
      productId: json['productId'] ?? json['product_id'] ?? '',
      quantity: (json['quantity'] ?? 1).toInt(),
      product: enrichedProduct,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      if (product != null) 'product': product!.toJson(),
    };
  }

  // Convenience getters for display (prevents null checks everywhere)
  String get name => product?.name ?? 'Unknown Product';
  double get price => product?.price ?? 0.0;
  String get imageUrl => product?.firstImage ?? 'https://via.placeholder.com/150';
  String get sellerId => product?.sellerId ?? '';
  double get totalPrice => price * quantity;
}
