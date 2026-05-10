// lib/features/seller/service/seller_analytics_provider.dart

import 'package:flutter/material.dart';
import 'package:swipify/features/seller/model/seller_analytics_model.dart';
import 'package:swipify/services/api_service.dart';

class SellerAnalyticsProvider with ChangeNotifier {
  AnalyticsResponse? _analytics;
  bool _isLoading = false;
  String? _error;

  AnalyticsResponse? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAnalytics(String sellerId, {int days = 7}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('/seller/analytics/daily-sales', queryParams: {
        'seller_id': sellerId,
        'days': days.toString(),
      });

      if (response != null) {
        _analytics = AnalyticsResponse.fromJson(response);
      } else {
        _error = "Failed to fetch analytics data";
      }
    } catch (e) {
      _error = e.toString();
      print("[ANALYTICS PROVIDER ERROR] $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _analytics = null;
    _error = null;
    notifyListeners();
  }
}
