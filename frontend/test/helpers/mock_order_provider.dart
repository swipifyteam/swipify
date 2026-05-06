import 'package:flutter/material.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/orders/service/order_provider.dart';

class MockOrderProvider extends ChangeNotifier implements OrderProvider {
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;

  @override
  List<OrderModel> get orders => _orders;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;

  int _toPayCount = 0;
  int _toShipCount = 0;
  int _toReceiveCount = 0;
  int _completedCount = 0;

  @override
  int get toPayCount => _toPayCount;
  @override
  int get toShipCount => _toShipCount;
  @override
  int get toReceiveCount => _toReceiveCount;
  @override
  int get completedCount => _completedCount;

  void setMockCounts({int toPay = 0, int toShip = 0, int toReceive = 0, int completed = 0}) {
    _toPayCount = toPay;
    _toShipCount = toShip;
    _toReceiveCount = toReceive;
    _completedCount = completed;
    notifyListeners();
  }

  @override
  Future<void> fetchUserOrders(String uid) async {
    // Default mock behavior: do nothing or use existing _orders
  }

  @override
  void setOrders(List<OrderModel> orders) {
    _orders = orders;
    notifyListeners();
  }

  void setMockLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setMockError(String? error) {
    _error = error;
    notifyListeners();
  }

  @override
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    // Mock: no-op
  }

  @override
  Future<bool> confirmCod(String orderId) async {
    // Mock implementation for confirmCod
    return true;
  }
}
