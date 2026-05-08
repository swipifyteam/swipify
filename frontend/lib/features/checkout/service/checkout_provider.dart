// lib/features/checkout/service/checkout_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:swipify/models/address_model.dart';
import 'package:swipify/models/shipping_option_model.dart';
import 'package:swipify/features/cart/model/cart_item_model.dart';
import 'package:swipify/models/voucher_model.dart';
import 'package:swipify/services/api_service.dart';
import 'package:swipify/services/payment_service.dart';

class CheckoutProvider with ChangeNotifier {
  AddressModel? _selectedAddress;
  ShippingOptionModel? _selectedShippingOption;
  final Map<String, VoucherApplyResult> _shopVouchers = {};
  VoucherApplyResult? _shippingVoucher;
  List<VoucherModel> _availableVouchers = [];
  List<CartItemModel> _cartItems = [];
  String _userId = '';
  double _backendShippingFee = 0.0;
  double _backendTotal = 0.0;
  String? _errorMessage;

  // ── Loading state split ──────────────────────────────────────────────────
  // isPlacingOrder: blocks the PLACE ORDER button + shows full overlay
  bool _isPlacingOrder = false;
  // isApplyingVoucher: shows a small indicator on the voucher row
  bool _isApplyingVoucher = false;
  // isInitialized: used by CheckoutScreen to decide whether to show the
  // full-page spinner on first load vs. just rendering with existing data.
  bool _isInitialized = false;

  // ── Public getters ───────────────────────────────────────────────────────
  List<CartItemModel> get cartItems => _cartItems;
  AddressModel? get selectedAddress => _selectedAddress;
  ShippingOptionModel? get selectedShippingOption => _selectedShippingOption;
  Map<String, VoucherApplyResult> get appliedShopVouchers => _shopVouchers;
  VoucherApplyResult? get appliedShippingVoucher => _shippingVoucher;
  List<VoucherModel> get availableVouchers => _availableVouchers;
  bool get isPlacingOrder => _isPlacingOrder;
  bool get isApplyingVoucher => _isApplyingVoucher;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  double get backendShippingFee => _backendShippingFee;
  double get total => _backendTotal;

  // Kept for backward compat — CheckoutScreen's button uses isPlacingOrder now
  bool get isLoading => _isPlacingOrder || _isApplyingVoucher;

  // ── Derived ──────────────────────────────────────────────────────────────
  Map<String, List<CartItemModel>> get itemsBySeller {
    final Map<String, List<CartItemModel>> groups = {};
    for (var item in _cartItems) {
      groups.putIfAbsent(item.sellerId, () => []).add(item);
    }
    return groups;
  }

  double sellerSubtotal(String sellerId) =>
      itemsBySeller[sellerId]?.fold(0.0, (sum, item) => sum! + item.totalPrice) ?? 0.0;

  double get subtotal => _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get shopDiscounts =>
      _shopVouchers.values.fold(0.0, (sum, v) => sum + v.discount);

  double get shippingDiscount => _shippingVoucher?.discount ?? 0.0;

  // ── Initialization ────────────────────────────────────────────────────────
  /// Called exactly once per screen visit from didChangeDependencies.
  void setCartItems(String userId, List<CartItemModel> items) async {
    if (_isInitialized && _userId == userId) return;
    _isInitialized = true;
    _userId = userId;
    _cartItems = items;
    notifyListeners(); // single notify: items are ready, screen can render

    // Silent background fetches — no leading notifyListeners()
    await _silentFetchVouchers(userId);
    await _silentRecalculate();
  }

  // ── Background (silent) helpers ──────────────────────────────────────────
  /// Fetches vouchers without flickering: only notifies once at the end.
  Future<void> _silentFetchVouchers(String userId) async {
    if (_cartItems.isEmpty) return;
    try {
      final sellerIds = itemsBySeller.keys.toList();
      final cartTotals = {
        for (var sId in sellerIds) sId: sellerSubtotal(sId),
      };
      // Important: this now fetches only claimed vouchers for the user
      _availableVouchers = await ApiService.getAvailableVouchers(
        userId: userId,
        sellerIds: sellerIds,
        cartTotals: cartTotals,
      );
    } catch (e) {
      debugPrint('[VOUCHER FETCH] $e');
    } finally {
      notifyListeners();
    }
  }

  /// Recalculates totals without flickering: only notifies once at the end.
  Future<void> _silentRecalculate() async {
    final distanceKm = _selectedAddress != null ? 5.0 : 0.0;
    final weightKg = _cartItems.fold(0.0, (sum, i) => sum + i.quantity * 0.5);
    double currentSubtotal = subtotal - shopDiscounts;
    if (currentSubtotal < 0) currentSubtotal = 0;

    try {
      final res = await ApiService.calculateTotal(
        distanceKm: distanceKm,
        weightKg: weightKg,
        subtotal: currentSubtotal,
        shippingFee: _selectedShippingOption?.fee,
      );
      double rawFee = (res['shipping_fee'] as num).toDouble();
      _backendShippingFee = (rawFee - shippingDiscount).clamp(0.0, double.infinity);
      _backendTotal = currentSubtotal + _backendShippingFee;
    } catch (e) {
      _errorMessage = 'Total calculation failed: $e';
    } finally {
      notifyListeners();
    }
  }

  // ── Public: user-triggered fetch (REFRESH button) ─────────────────────────
  Future<void> fetchAvailableVouchers(String userId) async {
    await _silentFetchVouchers(userId);
  }

  // ── Public: recalculate (called after address / shipping / voucher change) ─
  Future<void> recalculateBackendTotal() async {
    await _silentRecalculate();
  }

  // ── Apply / Remove Voucher ────────────────────────────────────────────────
  Future<void> applyVoucher(String sellerId, String code) async {
    _isApplyingVoucher = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.applyVoucher(
        userId: _userId,
        sellerId: sellerId,
        voucherCode: code,
        cartTotal: sellerSubtotal(sellerId),
        shippingFee: _backendShippingFee,
      );

      if (result.discount > 0) {
        final voucherInfo = _availableVouchers.firstWhere(
          (v) => v.code == code,
          orElse: () => VoucherModel(
            id: '',
            brandId: sellerId,
            code: code,
            title: code,
            description: '',
            discountType: 'fixed',
            discountTarget: 'SUBTOTAL',
            discountValue: 0,
            minimumSpend: 0,
            endDate: DateTime.now(),
            startDate: DateTime.now(),
            usageLimit: 0,
            usedCount: 0,
            remainingQuantity: 0,
            claimedCount: 0,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );

        if (voucherInfo.discountTarget == 'SHIPPING') {
          _shippingVoucher = result;
        } else {
          _shopVouchers[sellerId] = result;
        }
      } else {
        _errorMessage = "Voucher code '$code' is not valid for this order.";
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isApplyingVoucher = false;
      notifyListeners();
      await _silentRecalculate(); // recalculate silently (notifies once inside)
    }
  }

  void removeVoucher(String sellerId) async {
    if (_shippingVoucher?.sellerId == sellerId) {
      _shippingVoucher = null;
    } else {
      _shopVouchers.remove(sellerId);
    }
    notifyListeners();
    await _silentRecalculate();
  }

  // ── Address / Shipping selection ──────────────────────────────────────────
  void selectAddress(AddressModel address) {
    _selectedAddress = address;
    _selectedShippingOption = null;
    notifyListeners(); // one notify — widget's didChangeDependencies picks up address change
  }

  void selectShippingOption(ShippingOptionModel option) async {
    _selectedShippingOption = option;
    notifyListeners();
    await _silentRecalculate();
  }

  // ── Payment Method selection ──────────────────────────────────────────────
  String _selectedPaymentMethod = 'cod';
  String get selectedPaymentMethod => _selectedPaymentMethod;

  void selectPaymentMethod(String method) {
    _selectedPaymentMethod = method;
    notifyListeners();
  }

  // ── Helper: build seller groups for payment API ───────────────────────────
  List<Map<String, dynamic>> _buildSellerGroups() {
    final groups = <Map<String, dynamic>>[];
    for (final sId in itemsBySeller.keys) {
      final items = itemsBySeller[sId]!;
      final shopVoucher = _shopVouchers[sId];
      final shipVoucher =
          (_shippingVoucher?.sellerId == sId) ? _shippingVoucher : null;
      final totalDiscount =
          (shopVoucher?.discount ?? 0.0) + (shipVoucher?.discount ?? 0.0);

      groups.add({
        'seller_id': sId,
        'items': items
            .map((i) => {
                  'product_id': i.productId,
                  'name': i.name,
                  'price': i.price,
                  'quantity': i.quantity,
                  'image_url': i.imageUrl,
                })
            .toList(),
        'total_price': items.fold(0.0, (sum, i) => sum + i.totalPrice),
        'discount_amount': totalDiscount,
        'voucher_id': shopVoucher?.voucherId ?? shipVoucher?.voucherId,
      });
    }
    return groups;
  }

  // ── Place Order ───────────────────────────────────────────────────────────
  Future<String?> placeOrder(String userId) async {
    _isPlacingOrder = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_selectedAddress == null) throw Exception('Please select a delivery address.');
      if (_selectedShippingOption == null) throw Exception('Please select a shipping option.');
      if (_cartItems.isEmpty) throw Exception('Your cart is empty.');

      if (_selectedPaymentMethod == 'cod') {
        // ── COD: Create orders immediately ──────────────────────────────
        for (final sId in itemsBySeller.keys) {
          final items = itemsBySeller[sId]!;
          final shopVoucher = _shopVouchers[sId];
          final shipVoucher =
              (_shippingVoucher?.sellerId == sId) ? _shippingVoucher : null;
          final totalDiscount =
              (shopVoucher?.discount ?? 0.0) + (shipVoucher?.discount ?? 0.0);

          final orderData = {
            'user_id': userId,
            'seller_id': sId,
            'items': items
                .map((i) => {
                      'product_id': i.productId,
                      'name': i.name,
                      'price': i.price,
                      'quantity': i.quantity,
                      'image_url': i.imageUrl,
                    })
                .toList(),
            'total_price': items.fold(0.0, (sum, i) => sum + i.totalPrice),
            'discount_amount': totalDiscount,
            'voucher_id': shopVoucher?.voucherId ?? shipVoucher?.voucherId,
            'selected_shipping_option': _selectedShippingOption!.toJson(),
            'shipping_address': _selectedAddress!.toSnapshot(),
          };

          final headers = await ApiService.getHeaders();
          final response = await http.post(
            Uri.parse('${ApiService.baseUrl}/orders/'),
            headers: headers,
            body: json.encode(orderData),
          );

          if (response.statusCode != 200 && response.statusCode != 201) {
            throw Exception('Failed to place order for seller $sId: ${response.body}');
          }
        }

        debugPrint('[CHECKOUT] COD orders placed successfully');
        return 'cod';
      } else {
        // ── GCash / Card: Payment first, orders created by webhook ──────
        final paymentService = PaymentService();
        final checkoutUrl = await paymentService.createPaymentSource(
          sellerGroups: _buildSellerGroups(),
          amount: _backendTotal,
          paymentMethod: _selectedPaymentMethod,
          shippingOption: _selectedShippingOption!.toJson(),
          shippingAddress: _selectedAddress!.toSnapshot(),
        );
        debugPrint('[CHECKOUT] Payment source created, redirecting to: $checkoutUrl');
        return checkoutUrl;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      _isPlacingOrder = false;
      notifyListeners();
    }
  }
}
