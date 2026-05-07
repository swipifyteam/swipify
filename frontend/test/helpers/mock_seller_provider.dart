// ============================================================
// test/helpers/mock_seller_provider.dart
// Mock SellerProvider for testing.
// ============================================================
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:swipify/features/seller/service/seller_provider.dart';
import 'package:swipify/features/seller/domain/entities/seller_entity.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/models/product_model.dart';

class MockSellerProvider extends ChangeNotifier implements SellerProvider {
  SellerStatus _status = SellerStatus.notApplied;
  
  @override
  SellerStatus get status => _status;
  
  void setMockStatus(SellerStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  double get totalEarnings => 0.0;

  @override
  int get totalOrders => 0;

  @override
  int get deliveredCount => 0;

  @override
  List<OrderModel> get orders => [];

  @override
  List<ProductModel> get products => [];

  @override
  SellerEntity? get seller => null;

  @override
  String get shopName => '';

  @override
  String get shopDescription => '';

  @override
  String? get logoUrl => null;

  @override
  String? get bannerUrl => null;

  @override
  bool get vacationMode => false;

  @override
  double get standardShippingFee => 120.0;

  @override
  double get expressShippingFee => 200.0;

  @override
  double get freeShippingThreshold => 0.0;

  @override
  bool get orderAlerts => true;

  @override
  bool get payoutAlerts => true;

  @override
  bool get settingsLoaded => false;

  @override
  Future<void> fetchDashboardData(String sellerId) async {}

  @override
  Future<void> fetchStats(String sellerId) async {}

  @override
  Future<void> fetchOrders(String sellerId) async {}

  @override
  Future<bool> updateOrderStatus(String orderId, String newStatus, String sellerId, {BuildContext? context}) async => true;

  @override
  Future<void> fetchProducts(String sellerId) async {}

  @override
  Future<void> loadShopSettings(String sellerId) async {}

  @override
  Future<bool> saveShopSettings(String sellerId, Map<String, dynamic> data) async => true;

  @override
  Future<void> loadSellerStatus(String uid) async {}

  @override
  Future<String> uploadIdentityImage(Uint8List bytes, String fileName, String mimeType) async => '';

  @override
  Future<void> submitApplication(Map<String, dynamic> data, {required String userId}) async {}

  @override
  Future<bool> addProduct(Map<String, dynamic> data, String sellerId) async => true;

  @override
  Future<void> deleteProduct(String productId, String sellerId) async {}

  @override
  Future<bool> updateProduct(String productId, Map<String, dynamic> data, String sellerId) async => true;

  @override
  String getSalesReportUrl(String sellerId) => '';

  @override
  Future<bool> createFlashSale(Map<String, dynamic> data) async => true;

  @override
  Future<List<dynamic>> getFlashSales(String sellerId) async => [];

  @override
  Future<bool> deleteFlashSale(String saleId) async => true;

  @override
  Future<bool> createBundleDeal(Map<String, dynamic> data) async => true;

  @override
  Future<List<dynamic>> getBundleDeals(String sellerId) async => [];

  @override
  Future<bool> deleteBundleDeal(String bundleId) async => true;

  @override
  Future<bool> saveLoyaltyConfig(Map<String, dynamic> data) async => true;

  @override
  Future<Map<String, dynamic>?> getLoyaltyConfig(String sellerId) async => null;

  @override
  void setVacationMode(bool v) {}

  @override
  void setOrderAlerts(bool v) {}

  @override
  void setPayoutAlerts(bool v) {}

  @override
  void setStandardShippingFee(double v) {}

  @override
  void setExpressShippingFee(double v) {}

  @override
  void setFreeShippingThreshold(double v) {}

  @override
  void startOrderStream(String sellerId) {}
}
