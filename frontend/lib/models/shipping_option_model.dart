class ShippingOptionModel {
  final String id;
  final String name;
  final double fee;
  final int estimatedDaysMin;
  final int estimatedDaysMax;
  final String estimatedDeliveryText;

  ShippingOptionModel({
    required this.id,
    required this.name,
    required this.fee,
    required this.estimatedDeliveryText,
    this.estimatedDaysMin = 3,
    this.estimatedDaysMax = 5,
  });

  /// Parses both the static /shipping/options format
  /// {id, name, base_fee, estimated_delivery} and the
  /// old calculated format {id, name, fee, estimated_days_min, estimated_days_max}.
  factory ShippingOptionModel.fromJson(Map<String, dynamic> json) {
    // Prefer base_fee (static endpoint), fall back to fee (calculate endpoint)
    final double parsedFee =
        (json['base_fee'] ?? json['fee'] ?? 0.0).toDouble();

    final int min = json['estimated_days_min'] ?? 3;
    final int max = json['estimated_days_max'] ?? 5;

    // Prefer string estimated_delivery (static endpoint),
    // fall back to building it from day range fields (calculate endpoint)
    String parsedDelivery;
    if (json['estimated_delivery'] != null) {
      parsedDelivery = json['estimated_delivery'] as String;
    } else {
      parsedDelivery = '$min-$max days';
    }

    return ShippingOptionModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      fee: parsedFee,
      estimatedDeliveryText: parsedDelivery,
      estimatedDaysMin: min,
      estimatedDaysMax: max,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fee': fee,
      'estimated_days_min': estimatedDaysMin,
      'estimated_days_max': estimatedDaysMax,
    };
  }

  /// Alias used in checkout_screen.dart
  String get estimatedDelivery => estimatedDeliveryText;
  /// Alias used in checkout_screen.dart
  double get baseFee => fee;
}
