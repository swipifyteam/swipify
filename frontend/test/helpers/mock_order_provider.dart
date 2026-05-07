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

  @override
  int get toPayCount => _orders.where((o) => o.status == 'pending').length;
  @override
  int get toShipCount => _orders.where((o) => o.status == 'processing' || o.status == 'paid').length;
  @override
  int get toReceiveCount => _orders.where((o) => o.status == 'shipped' || o.status == 'in_transit' || o.status == 'delivered').length;
  @override
  int get completedCount => _orders.where((o) => o.status == 'completed').length;
  @override
  int get cancelledCount => _orders.where((o) => o.status == 'cancelled' || o.status == 'refunded').length;

  @override
  List<OrderModel> ordersByTab(String tab) {
    switch (tab) {
      case 'to_pay':
        return _orders.where((o) => o.status == 'pending').toList();
      case 'to_ship':
        return _orders.where((o) => o.status == 'processing' || o.status == 'paid').toList();
      case 'to_receive':
        return _orders.where((o) => o.status == 'shipped' || o.status == 'in_transit' || o.status == 'delivered').toList();
      case 'completed':
        return _orders.where((o) => o.status == 'completed').toList();
      case 'cancelled':
        return _orders.where((o) => o.status == 'cancelled' || o.status == 'refunded').toList();
      default:
        return _orders;
    }
  }

  @override
  void fetchUserOrders(String uid) {}

  @override
  void setOrders(List<OrderModel> orders) {
    _orders = orders;
    notifyListeners();
  }

  void setMockLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setMockCounts({int toPay = 0, int toShip = 0, int toReceive = 0, int completed = 0, int cancelled = 0}) {
    // We can simulate this by adding dummy orders with these statuses
    _orders = [
      ...List.generate(toPay, (_) => OrderModel(id: 'p', status: 'pending', totalPrice: 0, items: [], userId: 'u', sellerId: 's', paymentStatus: 'unpaid', paymentMethod: 'online')),
      ...List.generate(toShip, (_) => OrderModel(id: 's', status: 'processing', totalPrice: 0, items: [], userId: 'u', sellerId: 's', paymentStatus: 'paid', paymentMethod: 'online')),
      ...List.generate(toReceive, (_) => OrderModel(id: 'r', status: 'shipped', totalPrice: 0, items: [], userId: 'u', sellerId: 's', paymentStatus: 'paid', paymentMethod: 'online')),
      ...List.generate(completed, (_) => OrderModel(id: 'c', status: 'completed', totalPrice: 0, items: [], userId: 'u', sellerId: 's', paymentStatus: 'paid', paymentMethod: 'online')),
      ...List.generate(cancelled, (_) => OrderModel(id: 'x', status: 'cancelled', totalPrice: 0, items: [], userId: 'u', sellerId: 's', paymentStatus: 'refunded', paymentMethod: 'online')),
    ];
    notifyListeners();
  }

  void setMockError(String? error) {
    _error = error;
    notifyListeners();
  }

  @override
  Future<void> updateOrderStatus(String orderId, String newStatus) async {}

  @override
  Future<bool> confirmCod(String orderId) async => true;
}
