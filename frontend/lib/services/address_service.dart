import 'package:swipify/models/address_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swipify/services/api_service.dart';

class AddressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch addresses directly from Firestore for real-time/low-latency access.
  /// This follows the Firestore-first pattern requested.
  static Future<List<AddressModel>> getAddresses(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .orderBy('created_at', descending: true)
          .get();
          
      return snapshot.docs.map((doc) => AddressModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      })).toList();
    } catch (e) {
      // Fallback to API if Firestore fails
      final response = await http.get(Uri.parse('${ApiService.baseUrl}/users/$userId/addresses'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => AddressModel.fromJson(item)).toList();
      }
      throw Exception('Failed to load addresses: $e');
    }
  }

  /// Create address via API to trigger backend logic (default address management, etc.)
  static Future<AddressModel> createAddress(AddressModel address) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/users/${address.userId}/addresses'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(address.toJson()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final result = AddressModel.fromJson(json.decode(response.body));
      // Update defaultAddressId in user doc if this is default
      if (result.isDefault) {
        await _updateUserDefaultAddress(result.userId, result.id);
      }
      return result;
    } else {
      throw Exception('Failed to create address: ${response.body}');
    }
  }

  /// Update address via API
  static Future<AddressModel> updateAddress(AddressModel address) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/users/${address.userId}/addresses/${address.id}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(address.toJson()),
    );
    if (response.statusCode == 200) {
      final result = AddressModel.fromJson(json.decode(response.body));
      if (result.isDefault) {
        await _updateUserDefaultAddress(result.userId, result.id);
      }
      return result;
    } else {
      throw Exception('Failed to update address: ${response.body}');
    }
  }

  /// Delete address via API
  static Future<void> deleteAddress(String addressId, String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/users/$userId/addresses/$addressId'),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete address');
    }
  }

  /// Helper to sync default_address_id in the user document
  static Future<void> _updateUserDefaultAddress(String userId, String addressId) async {
    await _firestore.collection('users').doc(userId).update({
      'default_address_id': addressId,
    });
  }
}

