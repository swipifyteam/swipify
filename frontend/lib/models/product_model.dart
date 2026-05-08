class ProductMedia {
  final String type; // 'image' or 'video'
  final String url;
  final String? thumbnailUrl; // Only for video

  ProductMedia({
    required this.type,
    required this.url,
    this.thumbnailUrl,
  });

  factory ProductMedia.fromJson(Map<String, dynamic> json) {
    return ProductMedia(
      type: json['type'] ?? 'image',
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'url': url,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
    };
  }
}

class ProductModel {
  final String id;
  final String sellerId;
  final String name;
  final String category;
  final double price;
  final int stock;
  final String description;
  final List<String> images; // Legacy
  final List<ProductMedia> media;
  final String? thumbnailUrl;
  final int videoCount;
  final int imageCount;
  final List<String> sizes;
  final List<String> colors;
  final double rating;
  final int likeCount;
  final int viewCount;
  final int followerCount;
  final double averageRating;
  final int totalReviews;
  final String shopId;
  final String shopName;
  final bool isPublished;

  const ProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.description,
    this.images = const [],
    this.media = const [],
    this.thumbnailUrl,
    this.videoCount = 0,
    this.imageCount = 0,
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

  /// Parse a ProductModel from a JSON map (API response).
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    var mediaList = (json['media'] as List?)
            ?.map((m) => ProductMedia.fromJson(m))
            .toList() ?? [];
    
    // Fallback if media is empty but images exist
    if (mediaList.isEmpty && json['images'] != null) {
      mediaList = (json['images'] as List)
          .map((img) {
            final url = img.toString();
            final isVideo = url.toLowerCase().contains('.mp4') || 
                            url.toLowerCase().contains('.mov') || 
                            url.toLowerCase().contains('.avi');
            return ProductMedia(
              type: isVideo ? 'video' : 'image', 
              url: url,
              thumbnailUrl: json['thumbnail_url'] // fallback thumbnail
            );
          })
          .toList();
    }

    return ProductModel(
      id: json['id'] ?? '',
      sellerId: json['sellerId'] ?? json['seller_id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? json['brandId'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toInt(),
      description: json['description'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      media: mediaList,
      thumbnailUrl: json['thumbnail_url'],
      videoCount: (json['video_count'] ?? 0).toInt(),
      imageCount: (json['image_count'] ?? 0).toInt(),
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

  /// Returns the first image URL, or video thumbnail, or placeholder.
  String get firstImage {
    // 1. Try explicit thumbnail
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl!;
    
    // 2. Try to find an image in media list
    if (media.isNotEmpty) {
      final firstImageItem = media.firstWhere((m) => m.type == 'image', orElse: () => media[0]);
      if (firstImageItem.type == 'image') return firstImageItem.url;
      if (firstImageItem.thumbnailUrl != null) return firstImageItem.thumbnailUrl!;
    }
    
    // 3. Fallback to images[0] only if it's not a known video
    if (images.isNotEmpty) {
      final img = images[0];
      final isVideo = img.toLowerCase().contains('.mp4') || 
                      img.toLowerCase().contains('.mov') || 
                      img.toLowerCase().contains('.avi');
      if (!isVideo) return img;
    }
    
    return 'https://picsum.photos/300';
  }

  String get primaryImage => firstImage;

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
      'media': media.map((m) => m.toJson()).toList(),
      'thumbnail_url': thumbnailUrl,
      'video_count': videoCount,
      'image_count': imageCount,
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
