// models/voucher_model.dart
// Data model for a Voucher fetched from the Swipify backend API.

class VoucherModel {
  final String id;
  final String code;
  final String title;
  final String description;
  final String discountType; // 'percentage', or 'fixed'
  final String discountTarget; // 'SUBTOTAL' or 'SHIPPING'
  final double discountValue;
  final double minimumSpend;
  final DateTime endDate;
  final DateTime? startDate;
  final DateTime? createdAt;
  final String? brandId; // Maps to seller_id
  final int usageLimit;
  final int usedCount;
  final int remainingQuantity;
  final int claimedCount;
  final bool isClaimed;
  final bool isActive;

  String? get sellerId => brandId;

  const VoucherModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountTarget,
    required this.discountValue,
    required this.minimumSpend,
    required this.endDate,
    this.startDate,
    this.createdAt,
    this.brandId,
    this.usageLimit = 0,
    this.usedCount = 0,
    this.remainingQuantity = 0,
    this.claimedCount = 0,
    this.isClaimed = false,
    this.isActive = true,
  });

  /// Parse a VoucherModel from a JSON map (API response).
  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      title: json['title'] ?? json['code'] ?? 'Voucher',
      description: json['description'] ?? 'No description available',
      discountType: json['discount_type'] ?? 'fixed',
      discountTarget: json['discount_target'] ?? 'SUBTOTAL',
      discountValue: (json['discount_value'] ?? 0).toDouble(),
      minimumSpend: (json['minimum_spend'] ?? 0).toDouble(),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : DateTime.now(),
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      brandId: json['seller_id'],
      usageLimit: json['usage_limit'] ?? 0,
      usedCount: json['used_count'] ?? 0,
      remainingQuantity: json['remaining_quantity'] ?? 0,
      claimedCount: json['claimed_count'] ?? 0,
      isClaimed: json['is_claimed'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }

  /// Human-readable discount label (e.g., "₱200 Off" or "15% Off").
  String get discountLabel {
    if (discountTarget == 'SHIPPING') return 'Free Shipping';
    if (discountType == 'percentage') return '${discountValue.toInt()}% Off';
    return '₱${discountValue.toStringAsFixed(0)} Off';
  }

  VoucherModel copyWith({bool? isClaimed}) {
    return VoucherModel(
      id: id,
      code: code,
      title: title,
      description: description,
      discountType: discountType,
      discountTarget: discountTarget,
      discountValue: discountValue,
      minimumSpend: minimumSpend,
      endDate: endDate,
      startDate: startDate,
      createdAt: createdAt,
      brandId: brandId,
      usageLimit: usageLimit,
      usedCount: usedCount,
      remainingQuantity: remainingQuantity,
      claimedCount: claimedCount,
      isClaimed: isClaimed ?? this.isClaimed,
      isActive: isActive,
    );
  }
}

class VoucherApplyResult {
  final double discount;
  final double finalTotal;
  final String voucherId;
  final String code;
  final String? sellerId;

  VoucherApplyResult({
    required this.discount,
    required this.finalTotal,
    required this.voucherId,
    required this.code,
    this.sellerId,
  });

  factory VoucherApplyResult.fromJson(Map<String, dynamic> json) {
    return VoucherApplyResult(
      discount: (json['discount'] ?? 0).toDouble(),
      finalTotal: (json['final_total'] ?? 0).toDouble(),
      voucherId: json['voucher_id'] ?? '',
      code: json['code'] ?? '',
      sellerId: json['seller_id'],
    );
  }
}
