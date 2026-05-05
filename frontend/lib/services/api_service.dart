// services/api_service.dart
// Centralized API service for communicating with the Swipify FastAPI backend.
// All HTTP calls go through this service — change baseUrl to point to your deployed URL.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:swipify/models/product_model.dart';

import 'package:swipify/models/cart_item_model.dart';
import 'package:swipify/models/notification_model.dart';
import 'package:swipify/models/seller_voucher_model.dart';
import 'package:swipify/models/user_model.dart';
import 'package:swipify/models/review_model.dart';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // Base URL for the FastAPI backend.
  // - Android emulator → use 10.0.2.2
  // - iOS simulator / Flutter Web / Desktop → use localhost
  static String get baseUrl {
  if (kIsWeb) {
    return dotenv.env['BASE_URL_WEB']!;
  } else if (Platform.isAndroid) {
    return dotenv.env['BASE_URL_ANDROID']!;
  } else {
    return dotenv.env['BASE_URL_DEFAULT']!;
  }
  }

  // ── Generic Helpers ──────────────────────────────────────────────────────────

  static Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('GET $path failed: ${response.statusCode} - ${response.body}');
  }

  static Future<dynamic> post(String path, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await getHeaders(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('POST $path failed: ${response.statusCode} - ${response.body}');
  }

  static Future<dynamic> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('DELETE $path failed: ${response.statusCode} - ${response.body}');
  }

  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    final error = json.decode(response.body);
    throw Exception(error['detail'] ?? 'Signup failed');
  }

  // ── SMS Authentication ───────────────────────────────────────────────────

  static Future<void> sendSmsOtp(String phoneNumber, String uid) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/sms/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone_number': phoneNumber, 'uid': uid}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to send SMS OTP');
    }
  }

  static Future<void> verifySmsOtp(String phoneNumber, String otp, String uid) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/sms/verify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone_number': phoneNumber, 'otp': otp, 'uid': uid}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to verify SMS OTP');
    }
  }

  // ── Users ────────────────────────────────────────────────────────────────

  /// Fetch user document for sync
  static Future<Map<String, dynamic>> getUserData(String uid) async {
    final response = await http.get(Uri.parse('$baseUrl/users/$uid'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load user data');
  }

  /// Update user document (general purpose)
  static Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$uid'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      debugPrint('[API] updateUserData failed: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to update user data');
    }
  }

  /// Check if a user exists with the given phone number.
  /// Returns user info if found, or null if not.
  static Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    try {
      final encodedPhone = Uri.encodeComponent(phone.trim());
      final response = await http.get(Uri.parse('$baseUrl/users/by-phone/$encodedPhone'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('[API] getUserByPhone error: $e');
      return null;
    }
  }


  // ── Products ──────────────────────────────────────────────────────────────

  /// Fetch all products from the backend.
  /// Fetch all products from the backend, filtering for those with valid sellers.
  static Future<List<ProductModel>> getProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('products') && data['products'] is List) {
          final List<dynamic> list = data['products'];
          return list
              .where((p) => p != null) // Avoid null items in list
              .map((p) => ProductModel.fromJson(p))
              .where((p) => p.sellerId.isNotEmpty || p.shopId.isNotEmpty) // "Only show products that has sellers"
              .toList();
        }
      }
      debugPrint('ApiService: getProducts failed or returned malformed data (${response.statusCode})');
    } catch (e) {
      debugPrint('ApiService: getProducts error: $e');
    }
    return [];
  }

  /// Search products by name query.
  static Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final url = Uri.parse('$baseUrl/products/search?q=${Uri.encodeComponent(query)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('products') && data['products'] is List) {
          final List<dynamic> list = data['products'];
          return list
              .where((p) => p != null)
              .map((p) => ProductModel.fromJson(p))
              .where((p) => p.sellerId.isNotEmpty || p.shopId.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('ApiService: searchProducts error: $e');
    }
    return [];
  }

  /// Fetch a single product by ID.
  static Future<ProductModel> getProduct(String productId) async {
    final response = await http.get(Uri.parse('$baseUrl/products/$productId'));
    if (response.statusCode == 200) {
      return ProductModel.fromJson(json.decode(response.body));
    }
    throw Exception('Product not found');
  }

  // ── Categories ───────────────────────────────────────────────────────────

  /// Fetch all categories from the backend.
  static Future<List<String>> getCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/categories'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List) {
          return data.map((category) => category.toString()).toList();
        } else if (data is Map && data.containsKey('categories') && data['categories'] is List) {
          final List<dynamic> categoriesList = data['categories'] as List<dynamic>;
          return categoriesList.map((category) {
            if (category is Map) {
              return category['name'].toString();
            }
            return category.toString();
          }).toList();
        } else {
          return [];
        }
      }
      debugPrint('ApiService: getCategories failed (${response.statusCode}): ${response.body}');
      throw Exception('Failed to load categories');
    } catch (e) {
      debugPrint('ApiService: getCategories error: $e');
      rethrow;
    }
  }

  /// Fetch products by category.
  static Future<List<ProductModel>> getProductsByCategory(String category) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products/category/${Uri.encodeComponent(category)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('products') && data['products'] is List) {
          final List<dynamic> list = data['products'];
          return list
              .where((p) => p != null)
              .map((p) => ProductModel.fromJson(p))
              .where((p) => p.sellerId.isNotEmpty || p.shopId.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('ApiService: getProductsByCategory error: $e');
    }
    return [];
  }

  // ── Cart ─────────────────────────────────────────────────────────────────

  /// Fetch all cart items for a user (includes embedded product data).
  static Future<List<CartItemModel>> getCart(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cart/$userId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('items') && data['items'] is List) {
          final List<dynamic> items = data['items'];
          return items.map((i) => CartItemModel.fromJson(i)).toList();
        }
      }
    } catch (e) {
      debugPrint('ApiService: getCart error: $e');
    }
    return [];
  }

  /// Add a product to the cart (or increment quantity if already there).
  static Future<void> addToCart(String userId, String productId, {int quantity = 1}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cart/add'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId, 'productId': productId, 'quantity': quantity}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add to cart: ${response.statusCode}');
    }
  }

  /// Remove a product from the cart entirely.
  static Future<void> removeFromCart(String userId, String productId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cart/remove'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId, 'productId': productId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove from cart: ${response.statusCode}');
    }
  }

  /// Update a cart item's quantity. Set quantity to 0 to remove.
  static Future<void> updateCartQuantity(String userId, String productId, int quantity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cart/update'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'productId': productId,
        'quantity': quantity,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update cart: ${response.statusCode}');
    }
  }

  // ── Vouchers ─────────────────────────────────────────────────────────────

  /// Fetch all available vouchers across the platform.
  static Future<List<SellerVoucherModel>> getVouchers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/vouchers'));
      if (response.statusCode == 200) {
        final dynamic decodedBody = json.decode(response.body);

        List<dynamic> list;
        if (decodedBody is List) {
          list = decodedBody;
        } else if (decodedBody is Map && decodedBody.containsKey('vouchers') && decodedBody['vouchers'] is List) {
          list = decodedBody['vouchers'] as List<dynamic>;
        } else {
          return [];
        }
        return list.map((v) => SellerVoucherModel.fromJson(v)).toList();
      }
      throw Exception('Failed to load vouchers: ${response.statusCode}');
    } catch (e) {
      debugPrint('ApiService: getVouchers error: $e');
      rethrow;
    }
  }

  /// Claim a voucher for a user. Throws an exception on duplicate claim.
  static Future<String> claimVoucher(String userId, String voucherId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vouchers/claim'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId, 'voucher_id': voucherId}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['message'];
    }
    // Return error message for display in UI
    final error = json.decode(response.body);
    throw Exception(error['detail'] ?? 'Failed to claim voucher');
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotifications(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/notifications/$userId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notificationsList = data['notifications'] as List?;
        return {
          'notifications': (notificationsList ?? [])
              .map((n) => NotificationModel.fromJson(n))
              .toList(),
          'unreadCount': (data['unreadCount'] ?? 0) as int,
        };
      }
    } catch (e) {
      debugPrint('[API] Error getNotifications: $e');
    }
    return {'notifications': <NotificationModel>[], 'unreadCount': 0};
  }

  /// Mark a list of notifications as read.
  static Future<void> markNotificationsRead(List<String> notificationIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/read'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'notificationIds': notificationIds}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notifications as read');
    }
  }
  // ── Seller ─────────────────────────────────────────────────────────────────

  /// Fetch seller status for the current user.
  static Future<Map<String, dynamic>> getSellerStatus(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/seller/status/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load seller status: ${response.statusCode}');
  }

  /// Submit a seller application.
  static Future<void> applyAsSeller(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seller/apply'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to apply as seller');
    }
  }

  /// Generic upload for identity verification (to Cloudinary).
  static Future<String> uploadIdentity(
    List<int> bytes,
    String filename,
    String contentType,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/seller/upload-identity'),
    );

    var multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    );
    request.files.add(multipartFile);

    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      return data['image_url'];
    } else {
      final respStr = await response.stream.bytesToString();
      final error = json.decode(respStr);
      throw Exception(error['detail'] ?? 'Failed to upload identity image');
    }
  }

  /// Upload chat media (image or video)
  static Future<String> uploadChatMedia(
    List<int> bytes,
    String filename,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/chats/upload-media'),
    );

    var multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    );
    request.files.add(multipartFile);

    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      return data['media_url'];
    } else {
      final respStr = await response.stream.bytesToString();
      final error = json.decode(respStr);
      throw Exception(error['detail'] ?? 'Failed to upload chat media');
    }
  }

  /// Trigger push notification for a new chat message
  static Future<void> sendChatNotification({
    required String receiverId,
    required String senderName,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chats/notify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'receiver_id': receiverId,
        'sender_name': senderName,
        'message': message,
      }),
    );
    if (response.statusCode != 200) {
      debugPrint('[API] sendChatNotification failed: ${response.body}');
    }
  }

  /// Upload a seller document using multipart/form-data.
  static Future<String> uploadSellerDocument(
    String sellerId,
    String docType,
    List<int> bytes,
    String filename,
    String contentType,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/seller/upload-document'),
    );

    request.fields['seller_id'] = sellerId;
    request.fields['doc_type'] = docType;

    var multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    );
    request.files.add(multipartFile);

    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      return data['file_url'];
    } else {
      final respStr = await response.stream.bytesToString();
      final error = json.decode(respStr);
      throw Exception(error['detail'] ?? 'Failed to upload document');
    }
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  /// Fetch all seller applications for admin
  static Future<List<dynamic>> getAllSellers() async {
    final response = await http.get(Uri.parse('$baseUrl/seller/admin/sellers'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['sellers'];
    }
    throw Exception('Failed to load seller applications');
  }

  /// Approve a seller application
  static Future<void> adminApproveSeller(String sellerId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seller/admin/approve'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'seller_id': sellerId}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to approve seller');
    }
  }

  /// Reject a seller application
  static Future<void> adminRejectSeller(String sellerId, {String? reason}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seller/admin/reject'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'seller_id': sellerId, 'reason': reason}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to reject seller');
    }
  }


  // ── Helper ────────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  static Future<Map<String, String>> getHeaders([String? _]) async {
    final token = await getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // ── Seller Products ────────────────────────────────────────────────────────

  /// Fetch all products for a specific seller
  static Future<List<ProductModel>> getSellerProducts(String sellerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/seller/products/$sellerId'),
      headers: await getHeaders(sellerId),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> list = data['products'];
      return list.map((p) => ProductModel.fromJson(p)).toList();
    }
    throw Exception('Failed to load seller products: ${response.statusCode}');
  }

  static Future<List<ProductModel>> getSellerProductsWithUrl(String pathAndQuery, String sellerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl$pathAndQuery'),
      headers: await getHeaders(sellerId),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> list = data['products'] ?? [];
      return list.map((p) => ProductModel.fromJson(p)).toList();
    }
    throw Exception('Failed to load seller products: ${response.statusCode}');
  }

  /// Create a new product for a seller
  static Future<ProductModel> createSellerProduct(Map<String, dynamic> data) async {
    final sellerId = data['sellerId'];
    final response = await http.post(
      Uri.parse('$baseUrl/seller/products'),
      headers: await getHeaders(sellerId),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      final res = json.decode(response.body);
      return ProductModel.fromJson(res['product']);
    }
    throw Exception('Failed to create product: ${response.body}');
  }

  /// Update an existing seller product
  static Future<void> updateSellerProduct(String productId, Map<String, dynamic> data) async {
    // Note: the backend route for update doesn't strictly check the token yet in the code I saw, 
    // but it's good practice. However, seller_products.py update_product doesn't have Depends(get_current_user_id)
    // Let's check it again.
    final response = await http.put(
      Uri.parse('$baseUrl/seller/products/$productId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update product: ${response.body}');
    }
  }

  /// Delete a seller product
  static Future<void> deleteSellerProduct(String productId) async {
    final response = await http.delete(Uri.parse('$baseUrl/seller/products/$productId'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete product: ${response.body}');
    }
  }

  /// Update product stock
  static Future<void> updateProductStock(String productId, int adjustment, String sellerId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/seller/products/$productId/stock'),
      headers: await getHeaders(sellerId),
      body: json.encode({'adjustment': adjustment}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update stock: ${response.body}');
    }
  }

  /// Upload product image
  static Future<String> uploadProductImage(List<int> bytes, String filename, String sellerId) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/seller/products/upload-image'),
    );
    request.headers.addAll({
        'Authorization': 'Bearer $sellerId',
    });

    var multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    );
    request.files.add(multipartFile);

    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      return data['image_url'];
    } else {
      final respStr = await response.stream.bytesToString();
      final error = json.decode(respStr);
      throw Exception(error['detail'] ?? 'Failed to upload product image');
    }
  }

  // ── Seller Vouchers ────────────────────────────────────────────────────────

  /// Create a new voucher for a seller.
  static Future<SellerVoucherModel> createVoucher(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seller/vouchers'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return SellerVoucherModel.fromJson(json.decode(response.body));
    }
    final error = json.decode(response.body);
    throw Exception(error['detail'] ?? 'Failed to create voucher');
  }

  /// Fetch all vouchers for a specific seller.
  static Future<List<SellerVoucherModel>> getSellerVouchers(String sellerId) async {
    final response = await http.get(Uri.parse('$baseUrl/seller/vouchers/$sellerId'));
    if (response.statusCode == 200) {
      final List<dynamic> list = json.decode(response.body);
      return list.map((v) => SellerVoucherModel.fromJson(v)).toList();
    }
    throw Exception('Failed to load seller vouchers');
  }

  /// Fetch all available and valid vouchers for a checkout session.
  static Future<List<SellerVoucherModel>> getAvailableVouchers({
    required String userId,
    required List<String> sellerIds,
    required Map<String, double> cartTotals,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vouchers/available'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'seller_ids': sellerIds,
        'cart_totals': cartTotals,
      }),
    );
    if (response.statusCode == 200) {
      final dynamic decodedBody = json.decode(response.body);

      List<dynamic> list;
      if (decodedBody is List) {
        list = decodedBody;
      } else if (decodedBody is Map && decodedBody.containsKey('vouchers') && decodedBody['vouchers'] is List) {
        list = decodedBody['vouchers'] as List<dynamic>;
      } else {
        return [];
      }
      return list.map((v) => SellerVoucherModel.fromJson(v)).toList();
    }
    throw Exception('Failed to load available vouchers');
  }

  /// Update an existing voucher.
  static Future<SellerVoucherModel> updateVoucher(String voucherId, Map<String, dynamic> updateData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/seller/vouchers/$voucherId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(updateData),
    );
    if (response.statusCode == 200) {
      return SellerVoucherModel.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to update voucher');
  }

  /// Delete a voucher.
  static Future<void> deleteVoucher(String voucherId) async {
    final response = await http.delete(Uri.parse('$baseUrl/seller/vouchers/$voucherId'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete voucher');
    }
  }

  /// Apply a seller voucher to a cart subtotal.

  /// Apply a seller voucher to a cart subtotal.
  /// Apply a voucher to a cart subtotal.
  static Future<VoucherApplyResult> applyVoucher({
    required String voucherCode,
    required double cartTotal,
    required String sellerId,
    double? shippingFee,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vouchers/apply-voucher'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'seller_id': sellerId,
        'voucher_code': voucherCode,
        'cart_total': cartTotal,
        'shipping_fee': shippingFee ?? 0.0,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Adding sellerId to the result manually as it's useful for the Provider
      return VoucherApplyResult.fromJson({...data, 'seller_id': sellerId});
    }
    final error = json.decode(response.body);
    throw Exception(error['detail'] ?? 'Invalid voucher');
  }

  /// Calculate order totals using the backend engine API
  static Future<Map<String, dynamic>> calculateTotal({
    required double distanceKm,
    required double weightKg,
    required double subtotal,
    double? shippingFee,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/orders/calculate-total'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'distance_km': distanceKm,
        'weight_kg': weightKg,
        'subtotal': subtotal,
        'shipping_fee': shippingFee,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to calculate backend total');
  }

  // --- USER PROFILE ---

  static Future<String> uploadProfilePicture(String uid, List<int> bytes, String filename) async {
    final uri = Uri.parse('$baseUrl/users/upload-profile-picture');
    final request = http.MultipartRequest('POST', uri)
      ..fields['user_id'] = uid
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['profile_image'];
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to upload profile picture');
    }
  }

  static Future<UserModel> getUserProfile(String uid) async {
    final response = await http.get(Uri.parse('$baseUrl/users/$uid'));
    if (response.statusCode == 200) {
      return UserModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  static Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$uid'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update user profile');
    }
  }

  static Future<List<dynamic>> getUserOrders(String uid) async {
    final response = await http.get(Uri.parse('$baseUrl/users/$uid/orders'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load user orders');
    }
  }

  static Future<List<ReviewModel>> getUserReviews(String uid) async {
    final response = await http.get(Uri.parse('$baseUrl/users/$uid/reviews'));
    if (response.statusCode == 200) {
      final List<dynamic> list = json.decode(response.body);
      return list.map((r) => ReviewModel.fromJson(r)).toList();
    } else {
      throw Exception('Failed to load reviews');
    }
  }


  static Future<void> followSeller(String uid, String sellerId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/engagement/follow'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': uid, 'seller_id': sellerId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to follow seller');
    }
  }

  static Future<void> unfollowSeller(String uid, String sellerId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/engagement/unfollow?user_id=$uid&seller_id=$sellerId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to unfollow seller');
    }
  }

  static Future<List<dynamic>> getFollowedSellers(String uid) async {
    final response = await http.get(Uri.parse('$baseUrl/engagement/following/$uid'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['followed_sellers'];
    } else {
      throw Exception('Failed to load followed sellers');
    }
  }

  static Future<Map<String, dynamic>> getShopSettings(String sellerId) async {
    final response = await http.get(Uri.parse('$baseUrl/seller/shop/$sellerId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load shop settings: ${response.statusCode}');
  }
}
