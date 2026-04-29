// lib/features/seller/domain/repositories/seller_repository.dart
import 'dart:typed_data';

abstract class SellerRepository {
  Future<Map<String, dynamic>> getSellerStatus(String userId);
  Future<void> applySeller(Map<String, dynamic> data);
  Future<String> uploadSellerDocument(String sellerId, String docType, Uint8List fileBytes, String filename, String contentType);
}
