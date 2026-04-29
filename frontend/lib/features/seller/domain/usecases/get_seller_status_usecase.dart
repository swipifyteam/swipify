// lib/features/seller/domain/usecases/get_seller_status_usecase.dart
import 'package:swipify/features/seller/domain/repositories/seller_repository.dart';

class GetSellerStatusUseCase {
  final SellerRepository repository;

  GetSellerStatusUseCase(this.repository);

  Future<Map<String, dynamic>> execute(String userId) async {
    return await repository.getSellerStatus(userId);
  }
}
