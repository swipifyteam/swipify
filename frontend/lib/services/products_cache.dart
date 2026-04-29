import 'package:flutter/foundation.dart';
import 'package:swipify/models/product_model.dart';

/// Simple in-memory notifier for the global products list.
/// HomeScreen listens to this so newly created products can appear immediately.
class ProductsCache {
  static final ValueNotifier<List<ProductModel>> products = ValueNotifier<List<ProductModel>>([]);

  static void set(List<ProductModel> list) => products.value = List.unmodifiable(list);

  static void add(ProductModel p) {
    final current = List<ProductModel>.from(products.value);
    current.insert(0, p);
    products.value = List.unmodifiable(current);
  }
}
