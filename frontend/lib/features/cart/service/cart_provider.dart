// lib/features/cart/service/cart_provider.dart
// Cart Provider with real-time state management and multi-seller checkout logic.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swipify/features/cart/model/cart_item_model.dart';
import 'package:swipify/services/api_service.dart'; // Assuming ApiService is in this path

class CartProvider with ChangeNotifier {
  List<CartItemModel> _items = [];
  bool _isLoading = false;
  double _grandTotal = 0.0;
  String? _error;
  double _shippingFee = 0.0;
  String _estimatedDelivery = "";
  final Set<String> _selectedItemIds = {};

  // Redefined getters to explicitly match error messages
  List<CartItemModel> get items => _items; 
  bool get isLoading => _isLoading; 
  double get grandTotal => _grandTotal;
  double get totalPrice => _grandTotal; 

  // Selection Getters
  Set<String> get selectedItemIds => _selectedItemIds;
  List<CartItemModel> get selectedItems => 
      _items.where((item) => _selectedItemIds.contains(item.productId)).toList();
  
  double get selectedTotal {
    double total = 0;
    for (var item in selectedItems) {
      total += item.totalPrice;
    }
    return total;
  }

  bool isSelected(String productId) => _selectedItemIds.contains(productId);

  void toggleSelection(String productId) {
    if (_selectedItemIds.contains(productId)) {
      _selectedItemIds.remove(productId);
    } else {
      _selectedItemIds.add(productId);
    }
    notifyListeners();
  }

  void toggleSelectAll(bool selected) {
    if (selected) {
      _selectedItemIds.addAll(_items.map((e) => e.productId));
    } else {
      _selectedItemIds.clear();
    }
    notifyListeners();
  }

  // Getter for error
  String? get error => _error;

  // Setter for error to allow external modification and notification
  set error(String? value) {
    _error = value;
    notifyListeners();
  }

  // Other existing getters
  double get shippingFee => _shippingFee;
  String get estimatedDelivery => _estimatedDelivery;

  // Added itemCount getter as it was reported as missing
  int get itemCount => _items.length;

  void setShippingDetails(double fee, String delivery) {
    _shippingFee = fee;
    _estimatedDelivery = delivery;
    notifyListeners();
  }

  double get grandTotalWithShipping => _grandTotal + _shippingFee;

  // 1. FETCH CART (ENRICHED)
  Future<void> fetchCart(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _items = [];
      _grandTotal = 0.0;
      _error = null; // Clear error when user is null/empty
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null; // Clear previous errors
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('${ApiService.baseUrl}/cart/$userId'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List rawItems = data['items'] ?? [];
        
        // Ensure CartItemModel.fromJson can handle the data structure
        _items = rawItems.map((item) => CartItemModel.fromJson(item)).toList();
        _grandTotal = (data['grandTotal'] ?? 0.0).toDouble();
        
        debugPrint("[CART] Fetched ${_items.length} enriched items. Total: $_grandTotal");
      } else {
        // Use the setter for error
        error = "Failed to load cart: ${response.statusCode}";
      }
    } catch (e) {
      // Use the setter for error
      error = "Network error: $e";
      debugPrint("[CART ERROR] $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Legacy Alias for loadCart (called by some screens)
  Future<void> loadCart(String? userId) => fetchCart(userId);

  // 2. ADD TO CART
  Future<void> addToCart(String? userId, String productId, {int quantity = 1}) async {
    if (userId == null) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/cart/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      
      if (response.statusCode == 200) {
        await fetchCart(userId); // Refresh state
      } else {
        error = "Failed to add item to cart: ${response.statusCode}";
      }
    } catch (e) {
      error = "Network error adding to cart: $e";
      debugPrint("[CART ADD ERROR] $e");
    }
  }

  // 3. REORDER (Add multiple items)
  Future<void> reorderItems(String? userId, List<Map<String, dynamic>> products) async {
    if (userId == null) return;
    try {
      for (var p in products) {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/cart/add'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': userId,
            'productId': p['productId'],
            'quantity': p['quantity'],
          }),
        );
      }
      await fetchCart(userId);
    } catch (e) {
      error = "Network error during reorder: $e";
    }
  }

  // 4. UPDATE QUANTITY
  Future<void> updateQuantity(String? userId, String productId, int quantity) async {
    if (userId == null) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/cart/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
          'quantity': quantity,
        }),
      );
      
      if (response.statusCode == 200) {
        await fetchCart(userId);
      } else {
        error = "Failed to update item quantity: ${response.statusCode}";
      }
    } catch (e) {
      error = "Network error updating quantity: $e";
      debugPrint("[CART UPDATE ERROR] $e");
    }
  }

  // 4. REMOVE ITEM
  Future<void> removeItem(String? userId, String productId) async {
    if (userId == null) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/cart/remove'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'productId': productId,
        }),
      );
      
      if (response.statusCode == 200) {
        await fetchCart(userId);
      } else {
        error = "Failed to remove item from cart: ${response.statusCode}";
      }
    } catch (e) {
      error = "Network error removing item: $e";
      debugPrint("[CART REMOVE ERROR] $e");
    }
  }

  // 5. CLEAR CART (Local + Remote)
  Future<void> clearCart(String? userId) async {
    if (userId == null) return;
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/cart/clear'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );
      
      if (response.statusCode == 200) {
        _items = [];
        _grandTotal = 0.0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("[CART CLEAR ERROR] $e");
    }
  }
}
