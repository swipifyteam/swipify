class ShippingItemModel {
  final String productId;
  final String sellerId;
  final int quantity;
  final double weightKg;

  ShippingItemModel({
    required this.productId,
    required this.sellerId,
    required this.quantity,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'seller_id': sellerId,
      'quantity': quantity,
      'weight_kg': weightKg,
    };
  }
}
