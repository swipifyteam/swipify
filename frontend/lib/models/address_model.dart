class AddressModel {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String region;
  final String city;
  final String barangay;
  final String street;
  final String postalCode;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.region,
    required this.city,
    required this.barangay,
    required this.street,
    required this.postalCode,
    this.isDefault = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      region: json['region'] ?? '',
      city: json['city'] ?? '',
      barangay: json['barangay'] ?? '',
      street: json['street'] ?? '',
      postalCode: json['postal_code'] ?? '',
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'phone': phone,
      'region': region,
      'city': city,
      'barangay': barangay,
      'street': street,
      'postal_code': postalCode,
      'is_default': isDefault,
    };
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'full_name': fullName,
      'phone': phone,
      'region': region,
      'city': city,
      'barangay': barangay,
      'street': street,
      'postal_code': postalCode,
    };
  }

  String get fullAddress => '$street, $barangay, $city, $region, $postalCode';
}
