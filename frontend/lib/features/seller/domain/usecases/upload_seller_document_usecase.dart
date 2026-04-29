// lib/features/seller/domain/usecases/upload_seller_document_usecase.dart
import 'dart:typed_data';
import 'package:swipify/features/seller/domain/repositories/seller_repository.dart';

class UploadSellerDocumentUseCase {
  final SellerRepository repository;

  UploadSellerDocumentUseCase(this.repository);

  Future<String> execute(String sellerId, String docType, Uint8List fileBytes, String filename, String contentType) async {
    return await repository.uploadSellerDocument(sellerId, docType, fileBytes, filename, contentType);
  }
}
