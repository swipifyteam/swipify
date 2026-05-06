import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swipify/models/shipping_option_model.dart';
import 'package:swipify/services/api_service.dart';

class ShippingService {
  static Future<List<ShippingOptionModel>> getShippingOptions() async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/shipping/options'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ShippingOptionModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load shipping options');
    }
  }

  static Future<Map<String, dynamic>> calculateShipping({
    required String userId,
    required String addressId,
    required String shippingOptionId,
    required List<Map<String, dynamic>> cartItems,
    required String destinationPostalCode,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/shipping/calculate'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'items': cartItems,
        'destination_postal_code': destinationPostalCode,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Backend returns {options: [{id, name, fee, ...}]}
      // Pick the matching option or return first option's fee
      final List options = data['options'] ?? [];
      if (options.isEmpty) {
        return {'shipping_fee': 0.0, 'estimated_delivery': ''};
      }
      // Find the selected shipping option by id
      final matched = options.firstWhere(
        (o) => o['id'] == shippingOptionId,
        orElse: () => options.first,
      );
      final int minDays = matched['estimated_days_min'] ?? 3;
      final int maxDays = matched['estimated_days_max'] ?? 5;
      return {
        'shipping_fee': (matched['fee'] ?? 0.0).toDouble(),
        'estimated_delivery': '$minDays-$maxDays business days',
      };
    } else {
      final responseBody = response.body;
      throw Exception('Failed to calculate shipping. Status: ${response.statusCode}, Body: $responseBody');
    }
  }

  static Future<Map<String, dynamic>> createShipment({
    required String orderId,
    required String courierId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/shipping/create'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'order_id': orderId,
        'courier_id': courierId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create shipment: ${response.body}');
    }
  }
}
