class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? profileImage;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? defaultAddressId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.profileImage,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
    this.defaultAddressId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'User',
      email: json['email'] ?? '',
      role: json['role'] ?? 'buyer',
      profileImage: json['profile_image'],
      phoneNumber: json['phone_number'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      defaultAddressId: json['default_address_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'profile_image': profileImage,
      'phone_number': phoneNumber,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'default_address_id': defaultAddressId,
    };
  }
}
