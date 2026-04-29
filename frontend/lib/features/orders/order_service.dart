import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/services/api_service.dart';

class OrderService {
  /// Create a new order (from cart checkout)
  static Future<OrderModel> createOrder({
    required String userId,
    required String sellerId,
    required List<Map<String, dynamic>> items,
    required double totalPrice,
    required Map<String, dynamic> shippingOption,
    required Map<String, dynamic> shippingAddress,
    double discountAmount = 0.0,
    String? voucherId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/orders/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'seller_id': sellerId,
        'items': items,
        'total_price': totalPrice,
        'selected_shipping_option': shippingOption,
        'shipping_address': shippingAddress,
        'discount_amount': discountAmount,
        'voucher_id': voucherId,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return OrderModel.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create order: ${response.statusCode} - ${response.body}');
  }

  /// Create orders from cart (splits by seller)
  static Future<bool> createOrderFromCart({
    required String userId,
    required List<Map<String, dynamic>> cartItems,
    required double totalPrice,
    required Map<String, dynamic> shippingOption,
    required Map<String, dynamic> shippingAddress,
    double discountAmount = 0.0,
    String? voucherId,
  }) async {
    try {
      // 1. Group items by sellerId
      final Map<String, List<Map<String, dynamic>>> ordersBySeller = {};
      
      for (var item in cartItems) {
        // Enriched CartItemModel.toJson includes 'product': {'seller_id': ...}
        final sellerId = item['product']?['seller_id'] ?? 'unknown_seller';
        if (!ordersBySeller.containsKey(sellerId)) {
          ordersBySeller[sellerId] = [];
        }
        
        // Convert to OrderItem format expected by backend
        ordersBySeller[sellerId]!.add({
          'product_id': item['productId'],
          'name': item['product']?['name'] ?? 'Unknown',
          'price': (item['product']?['price'] ?? 0.0).toDouble(),
          'quantity': item['quantity'],
          'image_url': item['product']?['images'] != null && (item['product']?['images'] as List).isNotEmpty 
              ? (item['product']?['images'] as List)[0] 
              : null,
        });
      }

      // 2. Create an order for each seller
      bool allSent = true;
      for (var entry in ordersBySeller.entries) {
        final sellerId = entry.key;
        final sellerItems = entry.value;
        
        // Calculate subtotal for this seller
        double sellerSubtotal = 0;
        for (var item in sellerItems) {
          sellerSubtotal += item['price'] * item['quantity'];
        }

        // Send order
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/orders/'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': userId,
            'seller_id': sellerId,
            'items': sellerItems,
            'total_price': sellerSubtotal,
            'selected_shipping_option': shippingOption,
            'shipping_address': shippingAddress,
            'discount_amount': discountAmount, // Applying to the first/split orders? 
            'voucher_id': voucherId,
          }),
        );

        if (response.statusCode != 201 && response.statusCode != 200) {
          allSent = false;
          debugPrint("[ORDER ERROR] ${response.statusCode}: ${response.body}");
        }
      }

      return allSent;
    } catch (e) {
      debugPrint("[ORDER EXCEPTION] $e");
      return false;
    }
  }

  /// Create a new order directly (Buy Now)
  static Future<OrderModel> createBuyNowOrder({
    required String userId,
    required String productId,
    required int quantity,
    required Map<String, dynamic> shippingOption,
    required Map<String, dynamic> shippingAddress,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/orders/buy-now'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'product_id': productId,
        'quantity': quantity,
        'selected_shipping_option': shippingOption,
        'shipping_address': shippingAddress,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return OrderModel.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to process Buy Now order: ${response.statusCode} - ${response.body}');
  }

  /// Get all orders for a specific user
  static Future<List<OrderModel>> getUserOrders(String userId) async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/orders/user/$userId'));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final orders = data.map((json) => OrderModel.fromJson(json)).toList();
      debugPrint("[ORDERS FETCHED] ${orders.length}");
      return orders;
    }
    throw Exception('Failed to load user orders: ${response.statusCode}');
  }

  /// Get all orders for a specific seller
  static Future<List<OrderModel>> getSellerOrders(String sellerId) async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/orders/seller/$sellerId'));
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final orders = data.map((json) => OrderModel.fromJson(json)).toList();
      debugPrint("[SELLER ORDERS] ${orders.length}");
      return orders;
    }
    throw Exception('Failed to load seller orders: ${response.statusCode}');
  }

  /// Update the status of an order
  static Future<OrderModel> updateOrderStatus(String orderId, String newStatus) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/orders/$orderId/status'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': newStatus}),
    );

    if (response.statusCode == 200) {
      return OrderModel.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to update order status: ${response.statusCode}');
  }
}
