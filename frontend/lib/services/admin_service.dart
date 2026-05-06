import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AdminService {

  // --- MODULE 1: COMMAND CENTER ---
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin/dashboard/stats'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load dashboard stats');
  }

  // --- MODULE 2: USER MANAGEMENT ---
  static Future<Map<String, dynamic>> getUsers({
    int limit = 20,
    int offset = 0,
    String? role,
    String? search,
  }) async {
    var queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (role != null) queryParams['role'] = role;
    if (search != null) queryParams['search'] = search;

    var uri = Uri.parse('${ApiService.baseUrl}/admin/users').replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: await ApiService.getHeaders());
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load users');
  }

  static Future<void> updateUserStatus(String uid, String status) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin/users/$uid/status?status=$status'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update user status');
    }
  }

  static Future<void> updateUserRole(String uid, String role) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin/users/$uid/role?role=$role'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update user role');
    }
  }

  // --- MODULE 3: SELLER MANAGEMENT ---
  static Future<Map<String, dynamic>> getSellerApplications({
    int limit = 20,
    int offset = 0,
    String status = 'pending',
  }) async {
    var uri = Uri.parse('${ApiService.baseUrl}/admin/sellers/applications').replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
      'status': status,
    });
    
    final response = await http.get(uri, headers: await ApiService.getHeaders());
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load seller applications');
  }

  static Future<void> sellerApplicationDecision(String appId, String action, {String? storeName, String? reason}) async {
    final Map<String, dynamic> body = {
      'action': action,
    };
    if (storeName != null && storeName.trim().isNotEmpty) {
      body['storeName'] = storeName.trim();
    }
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }

    final headers = await ApiService.getHeaders();
    headers['Content-Type'] = 'application/json';

    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin/seller-applications/$appId/decision'),
      headers: headers,
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      final errorMsg = json.decode(response.body)['detail'] ?? 'Failed to process decision';
      throw Exception(errorMsg);
    }
  }

  /// Fetch full detail for a single seller application (Deep Dive modal).
  static Future<Map<String, dynamic>> getSellerApplicationDetail(String appId) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin/sellers/applications/$appId'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load application detail');
  }

  // --- MODULE 4: PRODUCT MODERATION ---
  static Future<Map<String, dynamic>> getProducts({
    int limit = 50,
    int offset = 0,
    String? status,
    String? category,
  }) async {
    var queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (status != null) queryParams['status'] = status;
    if (category != null) queryParams['category'] = category;

    var uri = Uri.parse('${ApiService.baseUrl}/admin/products').replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: await ApiService.getHeaders());
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load products');
  }

  static Future<void> updateProductStatus(String productId, String status, {String? reason}) async {
    var queryParams = {
      'status': status,
    };
    if (reason != null) queryParams['reason'] = reason;
    
    var uri = Uri.parse('${ApiService.baseUrl}/admin/products/$productId/status').replace(queryParameters: queryParams);
    
    final response = await http.put(uri, headers: await ApiService.getHeaders());
    if (response.statusCode != 200) {
      throw Exception('Failed to update product status');
    }
  }

  // --- MODULE 5: ORDER CONTROL CENTER ---
  static Future<Map<String, dynamic>> getOrders({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    var queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (status != null) queryParams['status'] = status;

    var uri = Uri.parse('${ApiService.baseUrl}/admin/orders').replace(queryParameters: queryParams);
    
    final response = await http.get(uri, headers: await ApiService.getHeaders());
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load orders');
  }

  static Future<void> forceCancelOrder(String orderId, String reason) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin/orders/$orderId/force-cancel?reason=$reason'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to force cancel order');
    }
  }

  // --- MODULE 6: FINANCE CENTER ---
  static Future<Map<String, dynamic>> getFinanceOverview() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin/finance/overview'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load finance overview');
  }

}
