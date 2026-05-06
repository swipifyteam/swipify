/// Data model for a product review fetched from the backend API.
class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String productId;
  final String productName;
  final double rating;
  final String comment;
  final List<String> imageUrls;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.productId,
    this.productName = '',
    required this.rating,
    required this.comment,
    required this.imageUrls,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'Anonymous',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      rating: (json['rating'] ?? json['rating_product'] ?? 5.0).toDouble(),
      comment: json['comment'] ?? '',
      imageUrls: List<String>.from(json['image_urls'] ?? json['images'] ?? []),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
