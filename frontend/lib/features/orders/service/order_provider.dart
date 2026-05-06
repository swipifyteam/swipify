import 'package:flutter/material.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/orders/order_service.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get toPayCount => _orders.where((o) => o.status == 'pending').length;
  int get toShipCount => _orders.where((o) => o.status == 'processing' || o.status == 'paid').length;
  int get toReceiveCount => _orders.where((o) => o.status == 'shipped' || o.status == 'in_transit' || o.status == 'delivered').length;
  int get completedCount => _orders.where((o) => o.status == 'completed').length;

  Future<void> fetchUserOrders(String uid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await OrderService.getUserOrders(uid);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final updatedOrder = await OrderService.updateOrderStatus(orderId, newStatus);
      // Update the order in the list
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = updatedOrder;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmCod(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final updatedOrder = await OrderService.confirmCod(orderId);
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _orders[index] = updatedOrder;
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setOrders(List<OrderModel> orders) {
    _orders = orders;
    notifyListeners();
  }
}
