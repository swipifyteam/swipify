import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/orders/order_service.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _ordersSubscription;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get toPayCount => _orders.where((o) => o.status == 'pending').length;
  int get toShipCount => _orders.where((o) => o.status == 'processing' || o.status == 'paid').length;
  int get toReceiveCount => _orders.where((o) => o.status == 'shipped' || o.status == 'in_transit' || o.status == 'delivered').length;
  int get completedCount => _orders.where((o) => o.status == 'completed').length;
  int get cancelledCount => _orders.where((o) => o.status == 'cancelled' || o.status == 'refunded').length;

  /// Filter orders by a display tab key
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

  void fetchUserOrders(String uid) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _ordersSubscription?.cancel();
    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      try {
        _orders = snapshot.docs.map((doc) {
          try {
            return OrderModel.fromJson({
              ...doc.data(),
              'id': doc.id,
            });
          } catch (e) {
            debugPrint('Error parsing order ${doc.id}: $e');
            rethrow;
          }
        }).toList();
        
        // Sort by created_at descending (client-side sort if not in index)
        _orders.sort((a, b) {
          final aTime = a.createdAt ?? '';
          final bTime = b.createdAt ?? '';
          return bTime.compareTo(aTime);
        });
        _isLoading = false;
        notifyListeners();
      } catch (e) {
        _error = 'Failed to parse orders: $e';
        _isLoading = false;
        notifyListeners();
      }
    }, onError: (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    _isLoading = true;
    notifyListeners();
    try {
      await OrderService.updateOrderStatus(orderId, newStatus);
      // Listener will handle local state update
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  Future<bool> confirmCod(String orderId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await OrderService.confirmCod(orderId);
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

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }
}

