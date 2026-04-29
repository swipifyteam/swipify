import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swipify/services/api_service.dart';

class AdminSettingsService {
  static Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin/settings'),
      headers: await ApiService.getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load settings: ${response.body}');
    }
  }

  static Future<void> updateSettings(Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin/settings'),
      headers: await ApiService.getHeaders(),
      body: json.encode(settings),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update settings: ${response.body}');
    }
  }
}

