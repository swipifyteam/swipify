import 'package:flutter/material.dart';
import 'package:swipify/models/seller_voucher_model.dart';
import 'package:swipify/services/api_service.dart';

class SellerVouchersProvider with ChangeNotifier {
  List<SellerVoucherModel> _vouchers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SellerVoucherModel> get vouchers => _vouchers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchVouchers(String sellerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _vouchers = await ApiService.getSellerVouchers(sellerId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createVoucher(Map<String, dynamic> voucherData) async {
    _isLoading = true;
    notifyListeners();
    try {
      final newVoucher = await ApiService.createVoucher(voucherData);
      _vouchers.add(newVoucher);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVoucher(String voucherId, Map<String, dynamic> updateData) async {
    _isLoading = true;
    notifyListeners();
    try {
      final updatedVoucher = await ApiService.updateVoucher(voucherId, updateData);
      final index = _vouchers.indexWhere((v) => v.id == voucherId);
      if (index != -1) {
        _vouchers[index] = updatedVoucher;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteVoucher(String voucherId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.deleteVoucher(voucherId);
      _vouchers.removeWhere((v) => v.id == voucherId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
