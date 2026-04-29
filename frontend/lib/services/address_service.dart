import 'package:swipify/models/address_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:swipify/services/api_service.dart';

class AddressService {
  static Future<List<AddressModel>> getAddresses(String userId) async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/users/$userId/addresses'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => AddressModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load addresses');
    }
  }

  static Future<AddressModel> createAddress(AddressModel address) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/users/${address.userId}/addresses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(address.toJson()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return AddressModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create address');
    }
  }

  static Future<AddressModel> updateAddress(AddressModel address) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/users/${address.userId}/addresses/${address.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(address.toJson()),
    );
    if (response.statusCode == 200) {
      return AddressModel.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update address');
    }
  }

  static Future<void> deleteAddress(String addressId, String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/users/$userId/addresses/$addressId'),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete address');
    }
  }
}
