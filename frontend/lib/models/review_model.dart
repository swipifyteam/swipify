class ReviewModel {
  final String id;
  final String userId;
  final String productId;
  final String productName;
  final double rating;
  final String comment;
  final List<String> images;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.rating,
    required this.comment,
    required this.images,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? 'Product',
      rating: (json['rating'] ?? 5.0).toDouble(),
      comment: json['comment'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
}
