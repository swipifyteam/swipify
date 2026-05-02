import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:swipify/services/api_service.dart';
import 'package:swipify/models/review_model.dart';

class ReviewService {
  static Future<void> submitReview({
    required String userId,
    required String productId,
    required String orderId,
    required int rating,
    required String comment,
    List<String> imageUrls = const [],
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/reviews'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'product_id': productId,
        'order_id': orderId,
        'rating': rating,
        'comment': comment,
        'image_urls': imageUrls,
      }),
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to submit review');
    }
    debugPrint('[REVIEW SUBMITTED] product=$productId rating=$rating');
  }

  /// Fetch reviews for a product with optional pagination.
  static Future<List<ReviewModel>> getProductReviews(
    String productId, {
    int limit = 10,
    int offset = 0,
  }) async {
    final url = Uri.parse(
      '${ApiService.baseUrl}/reviews/product/$productId?limit=$limit&offset=$offset',
    );
    debugPrint('[REVIEWS FETCHED] Requesting $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final reviews = data.map((r) => ReviewModel.fromJson(r)).toList();
      debugPrint('[PRODUCT REVIEWS LOADED] count=${reviews.length}');
      return reviews;
    }
    throw Exception('Failed to load reviews');
  }

  /// Legacy method — returns raw maps. Kept for backward compatibility.
  static Future<List<Map<String, dynamic>>> getReviews(String productId) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/reviews/product/$productId'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load reviews');
  }
}
