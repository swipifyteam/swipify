// lib/features/seller/domain/usecases/apply_seller_usecase.dart
import 'package:swipify/features/seller/domain/repositories/seller_repository.dart';

class ApplySellerUseCase {
  final SellerRepository repository;

  ApplySellerUseCase(this.repository);

  Future<void> execute(Map<String, dynamic> data) async {
    return await repository.applySeller(data);
  }
}
