import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swipify/models/address_model.dart';
import 'package:swipify/services/address_service.dart';

class AddressProvider extends ChangeNotifier {
  List<AddressModel> _addresses = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _addressSubscription;

  List<AddressModel> get addresses => _addresses;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AddressModel? get defaultAddress {
    try {
      return _addresses.firstWhere((a) => a.isDefault);
    } catch (_) {
      return _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  void fetchAddresses(String userId) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _addressSubscription?.cancel();
    _addressSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('addresses')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      _addresses = snapshot.docs.map((doc) => AddressModel.fromJson({
        ...doc.data(),
        'id': doc.id,
      })).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addAddress(AddressModel address) async {
    _isLoading = true;
    notifyListeners();
    try {
      await AddressService.createAddress(address);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAddress(AddressModel address) async {
    _isLoading = true;
    notifyListeners();
    try {
      await AddressService.updateAddress(address);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAddress(String addressId, String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await AddressService.deleteAddress(addressId, userId);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAsDefault(AddressModel address) async {
    final updated = AddressModel(
      id: address.id,
      userId: address.userId,
      fullName: address.fullName,
      phone: address.phone,
      region: address.region,
      city: address.city,
      barangay: address.barangay,
      street: address.street,
      postalCode: address.postalCode,
      isDefault: true,
    );
    await updateAddress(updated);
  }

  @override
  void dispose() {
    _addressSubscription?.cancel();
    super.dispose();
  }
}
