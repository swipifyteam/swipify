// models/product_model.dart
// Data model for a Product fetched from the Swipify backend API.

class ProductModel {
  final String id;
  final String sellerId;
  final String name;
  final String category;
  final double price;
  final int stock;
  final String description;
  final List<String> images;
  final List<String> sizes;
  final List<String> colors;
  final double rating;
  final int likeCount;
  final int viewCount;
  final int followerCount;
  final double averageRating;
  final int totalReviews;

  const ProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.description,
    required this.images,
    this.sizes = const [],
    this.colors = const [],
    required this.rating,
    this.likeCount = 0,
    this.viewCount = 0,
    this.followerCount = 0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.shopId = '',
    this.shopName = '',
    this.isPublished = true,
  });

  final String shopId;
  final String shopName;
  final bool isPublished;

  /// Parse a ProductModel from a JSON map (API response).
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      sellerId: json['sellerId'] ?? json['seller_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? json['brandId'] ?? '', // Fallback to brandId for older data
      price: (json['price'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toInt(),
      description: json['description'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      sizes: List<String>.from(json['sizes'] ?? []),
      colors: List<String>.from(json['colors'] ?? []),
      rating: (json['rating'] ?? 0.0).toDouble(),
      likeCount: (json['like_count'] ?? json['likeCount'] ?? 0).toInt(),
      viewCount: (json['view_count'] ?? json['viewCount'] ?? 0).toInt(),
      followerCount: (json['follower_count'] ?? json['followerCount'] ?? 0).toInt(),
      averageRating: (json['average_rating'] ?? json['averageRating'] ?? json['rating'] ?? 0.0).toDouble(),
      totalReviews: (json['total_reviews'] ?? json['totalReviews'] ?? 0).toInt(),
      shopId: json['shopId'] ?? json['shop_id'] ?? '',
      shopName: json['shopName'] ?? json['shop_name'] ?? '',
      isPublished: json['is_published'] ?? true,
    );
  }

  /// Returns the first image URL, or a placeholder if none available.
  String get primaryImage =>
      images.isNotEmpty ? images[0] : 'https://picsum.photos/300';

  /// Alias used by CartItemModel and other widgets.
  String get firstImage => primaryImage;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerId': sellerId,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'description': description,
      'images': images,
      'sizes': sizes,
      'colors': colors,
      'rating': rating,
      'like_count': likeCount,
      'view_count': viewCount,
      'follower_count': followerCount,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'shopId': shopId,
      'shopName': shopName,
      'is_published': isPublished,
    };
  }
}
