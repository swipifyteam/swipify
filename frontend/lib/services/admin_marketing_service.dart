import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AdminMarketingService {
  // --- MODULE 7: MARKETING CENTER ---

  /// List all platform-wide vouchers.
  static Future<List<dynamic>> getPlatformVouchers() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin/marketing/vouchers'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load platform vouchers');
  }

  /// Create a new platform-wide voucher.
  static Future<void> createPlatformVoucher(Map<String, dynamic> voucherData) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/admin/marketing/vouchers'),
      headers: await ApiService.getHeaders(),
      body: json.encode(voucherData),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create platform voucher');
    }
  }

  /// Delete a platform-wide voucher.
  static Future<void> deletePlatformVoucher(String voucherId) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/admin/marketing/vouchers/$voucherId'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete platform voucher');
    }
  }

  /// Update an existing platform-wide voucher (partial update).
  static Future<void> updatePlatformVoucher(String voucherId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin/marketing/vouchers/$voucherId'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update platform voucher');
    }
  }

  /// Get global marketing performance stats.
  static Future<Map<String, dynamic>> getMarketingStats() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin/marketing/stats'),
      headers: await ApiService.getHeaders(),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load marketing stats');
  }
}

