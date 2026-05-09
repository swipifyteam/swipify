import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/features/seller/domain/entities/seller_entity.dart';
import 'package:swipify/services/api_service.dart';

class SellerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _ordersSubscription;

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
      // Start real-time stream for orders (which also calculates stats)
      startOrderStream(sellerId);
      
      // Load other non-streamed data
      await Future.wait([
        loadShopSettings(sellerId),
        fetchProducts(sellerId),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 1. START REAL-TIME ORDER STREAM
  void startOrderStream(String sellerId) {
    _ordersSubscription?.cancel();
    
    debugPrint('[SELLER ORDERS] 📡 Starting stream for $sellerId');
    
    _ordersSubscription = _firestore
        .collection('orders')
        .where('seller_id', isEqualTo: sellerId)
        .snapshots()
        .listen((snapshot) {
      _orders = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return OrderModel.fromJson(data);
      }).toList();

      // Sort by date descending
      _orders.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));

      // 🚨 RE-CALCULATE STATS LOCALLY 🚨
      _calculateStats();
      
      debugPrint('[SELLER ORDERS] ✅ ${_orders.length} orders synced via stream');
      notifyListeners();
    }, onError: (e) {
      debugPrint('[SELLER ORDERS] ❌ Stream error: $e');
      _error = e.toString();
      notifyListeners();
    });
  }

  void _calculateStats() {
    double earnings = 0.0;
    int delivered = 0;

    for (var order in _orders) {
      final s = order.status.toLowerCase();
      // Match backend logic: total_price from 'delivered' or 'completed'
      if (s == 'delivered' || s == 'completed') {
        earnings += order.totalPrice;
        delivered++;
      }
    }

    _totalEarnings = earnings;
    _totalOrders = _orders.length;
    _deliveredCount = delivered;
    
    debugPrint('[SELLER STATS] 📊 Recalculated: earnings=$_totalEarnings orders=$_totalOrders delivered=$delivered');
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  // 2. FETCH REAL-TIME STATS (Legacy - now handled by _calculateStats)
  Future<void> fetchStats(String sellerId) async {
    // Keeping for compatibility but stats are now reactive
    _calculateStats();
  }

  // 3. FETCH SELLER ORDERS (Legacy - now handled by startOrderStream)
  Future<void> fetchOrders(String sellerId) async {
    if (_ordersSubscription == null) {
      startOrderStream(sellerId);
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
        // Stream handles local state update automatically via Firestore snapshot
        debugPrint('[UI REFRESHED] Stats reloaded via stream calculation');
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/seller/shop/$sellerId'),
        headers: {'Authorization': 'Bearer $token'},
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final token = await user.getIdToken();

      debugPrint('[SHOP SETTINGS] Saving for $sellerId: $data');
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/seller/shop/$sellerId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
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
