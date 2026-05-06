import 'package:flutter/foundation.dart';
import 'package:swipify/services/api_service.dart';

class PaymentService {
  /// Creates a PayMongo payment source by sending full checkout data.
  /// Orders are NOT created here — the backend webhook creates them on payment success.
  Future<String> createPaymentSource({
    required List<Map<String, dynamic>> sellerGroups,
    required double amount,
    required String paymentMethod,
    required Map<String, dynamic> shippingOption,
    required Map<String, dynamic> shippingAddress,
  }) async {
    try {
      final response = await ApiService.post('/payments/create', {
        'seller_groups': sellerGroups,
        'amount': amount,
        'payment_method': paymentMethod,
        'shipping_option': shippingOption,
        'shipping_address': shippingAddress,
      });
      return response['checkout_url'];
    } catch (e) {
      debugPrint('[PAYMENT SERVICE ERROR] $e');
      throw Exception('Failed to create payment source: $e');
    }
  }
}
