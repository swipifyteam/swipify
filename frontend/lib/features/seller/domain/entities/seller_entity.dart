// lib/features/seller/domain/entities/seller_entity.dart
enum SellerStatus {
  notApplied,
  pending,
  approved,
  rejected,
}

SellerStatus parseSellerStatus(String? statusStr) {
  switch (statusStr) {
    case 'PENDING':
      return SellerStatus.pending;
    case 'APPROVED':
      return SellerStatus.approved;
    case 'REJECTED':
      return SellerStatus.rejected;
    case 'NOT_APPLIED':
    default:
      return SellerStatus.notApplied;
  }
}

class SellerEntity {
  final String id;
  final String userId;
  final String storeName;
  final String sellerType;
  final SellerStatus status;

  const SellerEntity({
    required this.id,
    required this.userId,
    required this.storeName,
    required this.sellerType,
    required this.status,
  });
}
