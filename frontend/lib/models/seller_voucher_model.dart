class SellerVoucherModel {
  final String id;
  final String? sellerId; // Made nullable
  final String code;
  final String discountType;
  final String discountTarget;
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscount;
  final int usageLimit;
  final int usedCount;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  SellerVoucherModel({
    required this.id,
    this.sellerId, // Made nullable
    required this.code,
    required this.discountType,
    required this.discountTarget,
    required this.discountValue,
    required this.minOrderAmount,
    this.maxDiscount,
    required this.usageLimit,
    required this.usedCount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.createdAt,
  });

  factory SellerVoucherModel.fromJson(Map<String, dynamic> json) {
    return SellerVoucherModel(
      id: json['id'] ?? '',
      sellerId: json['seller_id'] as String?, // Nullable
      code: json['code'] ?? json['id'] ?? 'N/A', // Use id as fallback for code
      discountType: json['discount_type'] ?? 'percentage', // Default value
      discountTarget: json['discount_target'] ?? 'SUBTOTAL',
      discountValue: (json['discount_value'] as num? ?? 0.0).toDouble(), // Null-aware operator
      minOrderAmount: (json['min_order_amount'] as num? ?? json['minimumSpend'] as num? ?? 0.0).toDouble(), // Map minimumSpend
      maxDiscount: json['max_discount'] != null ? (json['max_discount'] as num).toDouble() : null,
      usageLimit: json['usage_limit'] ?? 999999, // Default large value
      usedCount: json['used_count'] ?? 0,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : DateTime.now(), // Default to now
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : (json['expiryDate'] != null ? DateTime.parse(json['expiryDate']) : DateTime.now().add(const Duration(days: 365))), // Map expiryDate
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(), // Default to now
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_id': sellerId,
      'code': code.toUpperCase(),
      'discount_type': discountType,
      'discount_target': discountTarget,
      'discount_value': discountValue,
      'min_order_amount': minOrderAmount,
      'max_discount': maxDiscount,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get discountLabel {
    String suffix = discountTarget == "SHIPPING" ? " Shipping Off" : " Off";
    if (discountType == 'percentage') {
      return '${discountValue.toInt()}%$suffix';
    } else {
      return '₱${discountValue.toStringAsFixed(0)}$suffix';
    }
  }
}

class VoucherApplyResult {
  final double discount;
  final double finalTotal;
  final String voucherId;
  final String code;
  final String sellerId;

  VoucherApplyResult({
    required this.discount,
    required this.finalTotal,
    required this.voucherId,
    required this.code,
    required this.sellerId,
  });

  factory VoucherApplyResult.fromJson(Map<String, dynamic> json) {
    return VoucherApplyResult(
      discount: (json['discount'] as num).toDouble(),
      finalTotal: (json['final_total'] as num).toDouble(),
      voucherId: json['voucher_id'],
      code: json['code'],
      sellerId: json['seller_id'] ?? '',
    );
  }
}
