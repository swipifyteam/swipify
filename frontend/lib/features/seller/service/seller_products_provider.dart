import 'package:flutter/material.dart';
import 'package:swipify/models/product_model.dart';
import 'package:swipify/services/api_service.dart';

class SellerProductsProvider with ChangeNotifier {
  List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _error;
  String? _lastSellerId;

  // Pagination & Filtering state
  int _currentPage = 1;
  bool _hasMore = true;
  String _searchQuery = '';
  String? _selectedCategory;
  bool? _isPublishedFilter;
  String _sortBy = 'newest';

  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  bool? get isPublishedFilter => _isPublishedFilter;
  String get sortBy => _sortBy;

  void setFilters({
    String? search,
    String? category,
    bool? isPublished,
    String? sort,
  }) {
    if (search != null) _searchQuery = search;
    if (category != null) _selectedCategory = category == 'All' ? null : category;
    if (isPublished != null) _isPublishedFilter = isPublished;
    if (sort != null) _sortBy = sort;
    
    _currentPage = 1;
    _hasMore = true;
    _products.clear();
    fetchSellerProducts();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _isPublishedFilter = null;
    _sortBy = 'newest';
    _currentPage = 1;
    _hasMore = true;
    _products.clear();
  }

  Future<void> loadMore() async {
    if (_hasMore && !_isLoading) {
      _currentPage++;
      await fetchSellerProducts(_lastSellerId, true);
    }
  }

  Future<void> fetchSellerProducts([String? sellerId, bool isLoadMore = false]) async {
    final id = sellerId ?? _lastSellerId;
    if (id == null) return;
    
    _lastSellerId = id;
    
    if (!isLoadMore) {
        _isLoading = true;
        _error = null;
        if (_products.isEmpty) { // preserve existing items on soft reload unless changed
          notifyListeners();
        }
    }

    try {
      debugPrint('[PRODUCT] Fetching seller products for: $id page=$_currentPage');
      
      // Building the URL with queries since ApiService doesn't have a complex getter
      // We will add the queries manually via ApiService.getSellerProducts if it supported it.
      // Wait, ApiService.getSellerProducts only takes sellerId right now.
      // Let's modify ApiService.getSellerProducts signature via another edit or just assume it is simple for now,
      // but the prompt instructed "with pagination, search, category, published, sort queries."
      // Let's build the URI here directly or modify ApiService. We can build it here for now if needed.
      
      // actually, ApiService.getSellerProducts just hits GET /seller/products/{sellerId}
      // I will adjust ApiService below, but for now let's construct the actual path.
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'limit': '10',
        'sort_by': _sortBy,
      };
      if (_searchQuery.isNotEmpty) queryParams['search'] = _searchQuery;
      if (_selectedCategory != null) queryParams['category'] = _selectedCategory!;
      if (_isPublishedFilter != null) queryParams['is_published'] = _isPublishedFilter.toString();

      final uriString = Uri(path: '/seller/products/$id', queryParameters: queryParams).toString();
      
      final list = await ApiService.getSellerProductsWithUrl(uriString, id);
      
      if (isLoadMore) {
        _products.addAll(list);
      } else {
        _products = list;
      }
      
      _hasMore = list.length >= 10;
      
    } catch (e) {
      _error = e.toString();
      debugPrint('[PRODUCT] Error fetching seller products: $e');
    } finally {
      if (!isLoadMore) _isLoading = false;
      notifyListeners();
    }
  }

  void removeProduct(String productId) {
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

  Future<bool> addProduct(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final product = await ApiService.createSellerProduct(data);
      _products.insert(0, product);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProduct(String productId, Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiService.updateSellerProduct(productId, data);
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final old = _products[index];
        _products[index] = ProductModel(
          id: old.id,
          name: data['name'] ?? old.name,
          category: data['category'] ?? old.category,
          price: data['price'] != null ? (data['price'] as num).toDouble() : old.price,
          stock: data['stock'] ?? old.stock,
          description: data['description'] ?? old.description,
          images: data['images'] != null ? List<String>.from(data['images']) : old.images,
          rating: old.rating,
          sellerId: old.sellerId,
          shopId: old.shopId,
          shopName: old.shopName,
          isPublished: data['is_published'] ?? old.isPublished,
        );
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

  Future<void> deleteProduct(String productId) async {
    try {
      await ApiService.deleteSellerProduct(productId);
      removeProduct(productId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> updateStock(String productId, int adjustment, String sellerId) async {
    try {
      await ApiService.updateProductStock(productId, adjustment, sellerId);
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final old = _products[index];
        _products[index] = ProductModel(
          id: old.id,
          name: old.name,
          category: old.category,
          price: old.price,
          stock: (old.stock + adjustment).clamp(0, 999999),
          description: old.description,
          images: old.images,
          rating: old.rating,
          sellerId: old.sellerId,
          shopId: old.shopId,
          shopName: old.shopName,
          isPublished: old.isPublished,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
