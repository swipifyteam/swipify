import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swipify/services/api_service.dart';

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
  }

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
