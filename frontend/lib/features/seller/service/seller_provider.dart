// lib/features/seller/service/seller_provider.dart
// Seller Dashboard state management — orders, stats, and seller shop settings.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/products/model/product_model.dart';
import 'package:swipify/features/seller/domain/entities/seller_entity.dart';
import 'package:swipify/services/api_service.dart';

class SellerProvider with ChangeNotifier {
  double _totalEarnings = 0.0;
  int _totalOrders = 0;
  int _deliveredCount = 0;

  List<OrderModel> _orders = [];
  List<ProductModel> _products = [];

  bool _isLoading = false;
  String? _error;
  SellerStatus _status = SellerStatus.notApplied;
  SellerEntity? _seller;

  // ── Shop settings (loaded from Firestore via /seller/shop/{uid}) ─────────
  String _shopName = '';
  String _shopDescription = '';
  String? _logoUrl;
  String? _bannerUrl;
  bool _vacationMode = false;
  double _standardShippingFee = 120.0;
  double _expressShippingFee = 200.0;
  double _freeShippingThreshold = 0.0;
  bool _orderAlerts = true;
  bool _payoutAlerts = true;
  bool _settingsLoaded = false;

  // Getters
  double get totalEarnings    => _totalEarnings;
  int    get totalOrders      => _totalOrders;
  int    get deliveredCount   => _deliveredCount;
  List<OrderModel>   get orders   => _orders;
  List<ProductModel> get products => _products;
  bool       get isLoading  => _isLoading;
  String?    get error      => _error;
  SellerStatus    get status  => _status;
  SellerEntity?   get seller  => _seller;

  // Shop settings getters
  String  get shopName              => _shopName;
  String  get shopDescription       => _shopDescription;
  String? get logoUrl               => _logoUrl;
  String? get bannerUrl             => _bannerUrl;
  bool    get vacationMode          => _vacationMode;
  double  get standardShippingFee   => _standardShippingFee;
  double  get expressShippingFee    => _expressShippingFee;
  double  get freeShippingThreshold => _freeShippingThreshold;
  bool    get orderAlerts           => _orderAlerts;
  bool    get payoutAlerts          => _payoutAlerts;
  bool    get settingsLoaded        => _settingsLoaded;

  // ── Setters for local UI binding ────────────────────────────────────────────
  void setVacationMode(bool v)            { _vacationMode = v; notifyListeners(); }
  void setOrderAlerts(bool v)             { _orderAlerts = v;  notifyListeners(); }
  void setPayoutAlerts(bool v)            { _payoutAlerts = v; notifyListeners(); }
  void setStandardShippingFee(double v)   { _standardShippingFee = v; notifyListeners(); }
  void setExpressShippingFee(double v)    { _expressShippingFee = v;  notifyListeners(); }
  void setFreeShippingThreshold(double v) { _freeShippingThreshold = v; notifyListeners(); }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchDashboardData(String sellerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        fetchStats(sellerId),
        fetchOrders(sellerId),
        loadShopSettings(sellerId),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 1. FETCH REAL-TIME STATS
  Future<void> fetchStats(String sellerId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/orders/stats/$sellerId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _totalEarnings  = (data['total_earnings']  ?? 0.0).toDouble();
        _totalOrders    = (data['total_orders']    ?? 0).toInt();
        _deliveredCount = (data['delivered_count'] ?? 0).toInt();
        debugPrint('[SELLER STATS] ✅ $sellerId → earnings=$_totalEarnings orders=$_totalOrders');
      } else {
        debugPrint('[SELLER STATS] ❌ ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[SELLER STATS] ❌ Exception: $e');
    }
  }

  // 2. FETCH SELLER ORDERS — handles both List and {"orders":[...]} shapes
  Future<void> fetchOrders(String sellerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/orders/seller/$sellerId'),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List raw;
        if (decoded is List) {
          raw = decoded;
        } else if (decoded is Map && decoded.containsKey('orders')) {
          raw = decoded['orders'] as List;
        } else {
          raw = [];
        }
        _orders = raw.map((o) => OrderModel.fromJson(o as Map<String, dynamic>)).toList();
        debugPrint('[SELLER ORDERS] ✅ ${_orders.length} orders for $sellerId');
      } else {
        debugPrint('[SELLER ORDERS] ❌ ${response.statusCode}: ${response.body}');
        _error = 'Failed to load orders: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('[SELLER ORDERS] ❌ Exception: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 3. UPDATE ORDER STATUS — proper await + snackbar feedback
  Future<bool> updateOrderStatus(
    String orderId,
    String newStatus,
    String sellerId, {
    BuildContext? context,
  }) async {
    debugPrint('[ORDER STATUS UPDATE REQUEST] $orderId → $newStatus');
    try {
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus}),
      );
      if (response.statusCode == 200) {
        debugPrint('[ORDER STATUS UPDATED] ✅ $orderId is now $newStatus');
        // Optimistically update local state immediately
        final idx = _orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) {
          final old = _orders[idx];
          _orders[idx] = OrderModel(
            id: old.id,
            userId: old.userId,
            sellerId: old.sellerId,
            items: old.items,
            totalPrice: old.totalPrice,
            status: newStatus,
            paymentMethod: old.paymentMethod,
            paymentStatus: old.paymentStatus,
            isCodConfirmed: old.isCodConfirmed,
            createdAt: old.createdAt,
            updatedAt: DateTime.now().toIso8601String(),
            shippingAddress: old.shippingAddress,
            shippingOption: old.shippingOption,
            shippingFee: old.shippingFee,
            trackingNumber: old.trackingNumber,
            logisticProvider: old.logisticProvider,
            discountAmount: old.discountAmount,
            voucherId: old.voucherId,
            shipmentId: old.shipmentId,
            statusHistory: old.statusHistory,
          );
          notifyListeners();
        }
        // Then refresh from server
        await fetchOrders(sellerId);
        await fetchStats(sellerId);
        debugPrint('[UI REFRESHED] Orders and stats reloaded');
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Order marked as ${newStatus[0].toUpperCase()}${newStatus.substring(1)}'),
            backgroundColor: const Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return true;
      } else {
        final detail = json.decode(response.body)['detail'] ?? response.body;
        debugPrint('[ORDER STATUS] ❌ ${response.statusCode}: $detail');
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $detail'),
            backgroundColor: const Color(0xFFE74C3C),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return false;
      }
    } catch (e) {
      debugPrint('[ORDER STATUS] ❌ Exception: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: const Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return false;
    }
  }

  // 4. FETCH SELLER PRODUCTS
  Future<void> fetchProducts(String sellerId) async {
    _error = null;
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/seller/products'),
        headers: await ApiService.getHeaders(sellerId),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List raw = decoded is List ? decoded : (decoded['products'] ?? []);
        _products = raw.map((p) => ProductModel.fromJson(p)).toList();
        notifyListeners();
      } else {
        _error = 'Failed to load products: ${response.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[SELLER PRODUCTS] ❌ $e');
    }
  }

  // 5. LOAD SHOP SETTINGS from Firestore via backend
  Future<void> loadShopSettings(String sellerId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/seller/shop/$sellerId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _shopName          = data['shop_name']         ?? '';
        _shopDescription   = data['description']       ?? '';
        _logoUrl           = data['logo_url'];
        _bannerUrl         = data['banner_url'];
        _vacationMode      = data['vacation_mode']     ?? false;
        final shipping     = data['shipping_settings'] as Map<String, dynamic>? ?? {};
        _standardShippingFee   = (shipping['standard_fee']          ?? 120.0).toDouble();
        _expressShippingFee    = (shipping['express_fee']           ?? 200.0).toDouble();
        _freeShippingThreshold = (shipping['free_threshold']        ?? 0.0).toDouble();
        _orderAlerts  = data['order_alerts']  ?? true;
        _payoutAlerts = data['payout_alerts'] ?? true;
        _settingsLoaded = true;
        debugPrint('[SHOP SETTINGS] ✅ Loaded for $sellerId: name=$_shopName');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SHOP SETTINGS] ⚠️ Could not load (shop may not exist yet): $e');
    }
  }

  // 6. SAVE SHOP SETTINGS
  Future<bool> saveShopSettings(String sellerId, Map<String, dynamic> data) async {
    try {
      debugPrint('[SHOP SETTINGS] Saving for $sellerId: $data');
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/seller/shop/$sellerId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        debugPrint('[SHOP SETTINGS] ✅ Saved');
        // Reload to sync
        await loadShopSettings(sellerId);
        return true;
      }
      debugPrint('[SHOP SETTINGS] ❌ ${response.statusCode}: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[SHOP SETTINGS] ❌ Exception: $e');
      return false;
    }
  }

  // 7. LOAD SELLER STATUS
  Future<void> loadSellerStatus(String uid) async {
    try {
      final data = await ApiService.getSellerStatus(uid);
      _status = parseSellerStatus(data['status']);
      if (data['seller'] != null) {
        final s = data['seller'];
        _seller = SellerEntity(
          id:         s['id']          ?? '',
          userId:     s['user_id']     ?? '',
          storeName:  s['store_name']  ?? '',
          sellerType: s['seller_type'] ?? '',
          status:     _status,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SELLER] Error loading status: $e');
    }
  }

  // 8. UPLOAD IDENTITY IMAGE
  Future<String> uploadIdentityImage(Uint8List bytes, String fileName, String mimeType) async {
    return await ApiService.uploadIdentity(bytes, fileName, mimeType);
  }

  // 9. SUBMIT APPLICATION
  Future<void> submitApplication(Map<String, dynamic> data, {required String userId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.applyAsSeller(data);
      _status = SellerStatus.pending;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 10. ADD PRODUCT
  Future<bool> addProduct(Map<String, dynamic> data, String sellerId) async {
    _error = null;
    try {
      await ApiService.createSellerProduct(data);
      await fetchProducts(sellerId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // 11. DELETE PRODUCT
  Future<void> deleteProduct(String productId, String sellerId) async {
    _error = null;
    try {
      await ApiService.deleteSellerProduct(productId);
      await fetchProducts(sellerId);
    } catch (e) {
      _error = e.toString();
    }
  }

  // 12. UPDATE PRODUCT
  Future<bool> updateProduct(String productId, Map<String, dynamic> data, String sellerId) async {
    _error = null;
    try {
      await ApiService.updateSellerProduct(productId, data);
      await fetchProducts(sellerId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // 13. DOWNLOAD SALES REPORT (CSV)
  // This triggers a browser download on web or returns the URL for mobile.
  String getSalesReportUrl(String sellerId) {
    return '${ApiService.baseUrl}/seller/orders/report/$sellerId';
  }

  // 14. MARKETING - FLASH SALES
  Future<bool> createFlashSale(Map<String, dynamic> data) async {
    _error = null;
    try {
      await ApiService.post('/marketing/flash-sales', data);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<List<dynamic>> getFlashSales(String sellerId) async {
    _error = null;
    try {
      return await ApiService.get('/marketing/flash-sales/$sellerId');
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<bool> deleteFlashSale(String saleId) async {
    _error = null;
    try {
      await ApiService.delete('/marketing/flash-sales/$saleId');
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // 15. MARKETING - BUNDLE DEALS
  Future<bool> createBundleDeal(Map<String, dynamic> data) async {
    _error = null;
    try {
      await ApiService.post('/marketing/bundle-deals', data);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<List<dynamic>> getBundleDeals(String sellerId) async {
    _error = null;
    try {
      return await ApiService.get('/marketing/bundle-deals/$sellerId');
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  Future<bool> deleteBundleDeal(String bundleId) async {
    _error = null;
    try {
      await ApiService.delete('/marketing/bundle-deals/$bundleId');
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // 16. MARKETING - LOYALTY
  Future<bool> saveLoyaltyConfig(Map<String, dynamic> data) async {
    _error = null;
    try {
      await ApiService.post('/marketing/loyalty/config', data);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getLoyaltyConfig(String sellerId) async {
    _error = null;
    try {
      return await ApiService.get('/marketing/loyalty/config/$sellerId');
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }
}
