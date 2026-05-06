// lib/features/seller/data/repositories/seller_repository_impl.dart
import 'dart:typed_data';
import 'package:swipify/features/seller/domain/repositories/seller_repository.dart';
import 'package:swipify/services/api_service.dart';

class SellerRepositoryImpl implements SellerRepository {
  @override
  Future<Map<String, dynamic>> getSellerStatus(String userId) async {
    return await ApiService.getSellerStatus(userId);
  }

  @override
  Future<void> applySeller(Map<String, dynamic> data) async {
    return await ApiService.applyAsSeller(data);
  }

  @override
  Future<String> uploadSellerDocument(String sellerId, String docType, Uint8List fileBytes, String filename, String contentType) async {
    return await ApiService.uploadSellerDocument(sellerId, docType, fileBytes, filename, contentType);
  }
}
