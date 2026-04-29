import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swipify/services/api_service.dart';

class AdminSupportService {
  /// Fetch support tickets. Backend returns paginated format:
  /// {"tickets": [...], "total": N}
  /// This service normalizes the response to always return a List.
  static Future<List<dynamic>> getTickets({String? status, String? priority}) async {
    String url = '${ApiService.baseUrl}/admin/support/tickets';
    List<String> params = [];
    if (status != null) params.add('status=$status');
    if (priority != null) params.add('priority=$priority');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await http.get(
      Uri.parse(url),
      headers: await ApiService.getHeaders(),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      // Handle both paginated format {"tickets": [...]} and raw list [...]
      if (decoded is Map) {
        return decoded['tickets'] ?? [];
      } else if (decoded is List) {
        return decoded;
      }
      return [];
    } else {
      throw Exception('Failed to load tickets: ${response.body}');
    }
  }

  /// Fetch disputes. Backend returns paginated format:
  /// {"disputes": [...], "total": N}
  static Future<List<dynamic>> getDisputes({String? status}) async {
    String url = '${ApiService.baseUrl}/admin/support/disputes';
    if (status != null) url += '?status=$status';

    final response = await http.get(
      Uri.parse(url),
      headers: await ApiService.getHeaders(),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      // Handle both paginated format {"disputes": [...]} and raw list [...]
      if (decoded is Map) {
        return decoded['disputes'] ?? [];
      } else if (decoded is List) {
        return decoded;
      }
      return [];
    } else {
      throw Exception('Failed to load disputes: ${response.body}');
    }
  }

  static Future<void> updateTicket(String ticketId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin/support/tickets/$ticketId'),
      headers: await ApiService.getHeaders(),
      body: json.encode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update ticket: ${response.body}');
    }
  }

  static Future<void> resolveDispute(String disputeId, String resolution, String? notes) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin/support/disputes/$disputeId/resolve?resolution=$resolution${notes != null ? '&notes=$notes' : ''}'),
      headers: await ApiService.getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resolve dispute: ${response.body}');
    }
  }
}
