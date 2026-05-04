// lib/features/seller/data/models/seller_model.dart
import 'package:swipify/features/seller/domain/entities/seller_entity.dart';

class SellerModel extends SellerEntity {
  const SellerModel({
    required super.id,
    required super.userId,
    required super.storeName,
    required super.sellerType,
    required super.status,
  });

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      storeName: json['storeName'] as String? ?? '',
      sellerType: json['sellerType'] as String? ?? '',
      status: parseSellerStatus(json['status'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'storeName': storeName,
      'sellerType': sellerType,
      'status': status.name.toUpperCase(),
    };
  }
}
