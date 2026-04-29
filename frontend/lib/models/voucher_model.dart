// models/voucher_model.dart
// Data model for a Voucher fetched from the Swipify backend API.

class VoucherModel {
  final String id;
  final String title;
  final String description;
  final String discountType; // 'shipping', 'percentage', or 'fixed'
  final double discountValue;
  final double minimumSpend;
  final String expiryDate;
  final String? brandId; // null = platform-wide voucher

  const VoucherModel({
    required this.id,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minimumSpend,
    required this.expiryDate,
    this.brandId,
  });

  /// Parse a VoucherModel from a JSON map (API response).
  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      discountType: json['discountType'] ?? 'fixed',
      discountValue: (json['discountValue'] ?? 0).toDouble(),
      minimumSpend: (json['minimumSpend'] ?? 0).toDouble(),
      expiryDate: json['expiryDate'] ?? '',
      brandId: json['brandId'],
    );
  }

  /// Human-readable discount label (e.g., "₱200 Off" or "15% Off").
  String get discountLabel {
    switch (discountType) {
      case 'percentage':
        return '${discountValue.toInt()}% Off';
      case 'fixed':
        return '₱${discountValue.toStringAsFixed(0)} Off';
      case 'shipping':
        return 'Free Shipping';
      default:
        return 'Discount';
    }
  }
}
