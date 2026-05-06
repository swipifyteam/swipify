import 'package:flutter/material.dart';

class StatusHistoryEntry {
  final String timestamp;
  final String? oldStatus;
  final String newStatus;
  final String? updatedBy;
  final String? notes;

  StatusHistoryEntry({
    required this.timestamp,
    this.oldStatus,
    required this.newStatus,
    this.updatedBy,
    this.notes,
  });

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StatusHistoryEntry(
      timestamp: json['timestamp'] ?? '',
      oldStatus: json['old_status'],
      newStatus: json['new_status'] ?? '',
      updatedBy: json['updated_by'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'old_status': oldStatus,
      'new_status': newStatus,
      'updated_by': updatedBy,
      'notes': notes,
    };
  }
}

class TrackingModel {
  final String? trackingNumber;
  final String status;
  final List<StatusHistoryEntry> statusHistory;
  final String? courier;

  TrackingModel({
    this.trackingNumber,
    required this.status,
    required this.statusHistory,
    this.courier,
  });

  factory TrackingModel.fromJson(Map<String, dynamic> json) {
    return TrackingModel(
      trackingNumber: json['tracking_number'],
      status: json['status'] ?? 'pending',
      statusHistory: (json['status_history'] as List? ?? [])
          .map((e) => StatusHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      courier: json['courier'],
    );
  }
}

class OrderItemModel {
  final String productId;
  final String name;     // Merged product info for record integrity
  final int quantity;
  final double price;    // Price at time of purchase
  final String? imageUrl;

  OrderItemModel({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.imageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      productId: json['product_id'] ?? json['productId'] ?? '',
      name: json['name'] ?? 'Product',
      quantity: (json['quantity'] ?? 1).toInt(),
      price: (json['price'] ?? 0.0).toDouble(),
      imageUrl: json['image_url'] ?? json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
       'product_id': productId,
       'name': name,
       'quantity': quantity,
       'price': price,
       if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}

class OrderModel {
  final String id;
  final String userId;
  final String sellerId;
  final List<OrderItemModel> items;
  final double totalPrice;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final bool isCodConfirmed;
  final Map<String, dynamic>? shippingAddress;
  final Map<String, dynamic>? shippingOption;
  final double? shippingFee;
  final String? createdAt;
  final String? updatedAt;
  final String? trackingNumber;
  final String? logisticProvider;
  final double? discountAmount;
  final String? voucherId;
  final String? shipmentId;
  final List<StatusHistoryEntry> statusHistory;

  OrderModel({
    required this.id,
    required this.userId,
    required this.sellerId,
    required this.items,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    this.isCodConfirmed = false,
    this.shippingAddress,
    this.shippingOption,
    this.shippingFee,
    this.createdAt,
    this.updatedAt,
    this.trackingNumber,
    this.logisticProvider,
    this.discountAmount,
    this.voucherId,
    this.shipmentId,
    this.statusHistory = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<OrderItemModel> itemsList = rawItems
        .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    final shippingDetails = json['shipping_details'] as Map<String, dynamic>? ?? json['shipping_option'] as Map<String, dynamic>?;
    final shippingFeeFromDetails = shippingDetails != null ? (shippingDetails['fee'] ?? 0.0).toDouble() : (json['shipping_fee'] ?? 0.0).toDouble();

    return OrderModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      sellerId: json['seller_id'] ?? json['sellerId'] ?? '',
      items: itemsList,
      totalPrice: (json['total_price'] ?? json['totalPrice'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'pending',
      paymentStatus: json['payment_status'] ?? 'unpaid',
      paymentMethod: json['payment_method'] ?? 'online',
      isCodConfirmed: json['is_cod_confirmed'] ?? false,
      shippingAddress: json['shipping_address'] as Map<String, dynamic>?,
      shippingOption: shippingDetails,
      shippingFee: shippingFeeFromDetails,
       createdAt: json['created_at'] ?? json['createdAt'],
      updatedAt: json['updated_at'] ?? json['updatedAt'],
      trackingNumber: json['tracking_number'],
      logisticProvider: json['logistic_provider'],
      discountAmount: (json['discount_amount'] ?? 0.0).toDouble(),
      voucherId: json['voucher_id'],
      shipmentId: json['shipment_id'],
      statusHistory: (json['status_history'] as List? ?? [])
          .map((e) => StatusHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'seller_id': sellerId,
      'items': items.map((i) => i.toJson()).toList(),
      'total_price': totalPrice,
      'status': status,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'is_cod_confirmed': isCodConfirmed,
      'shipping_address': shippingAddress,
      'shipping_option': shippingOption,
      'shipping_fee': shippingFee,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }


  // Helper getters for better display (UI polish)
  String get formattedStatus => status[0].toUpperCase() + status.substring(1);
  int get itemCount => items.length;

  static const List<String> validStatuses = [
    'pending',
    'processing',
    'shipped',
    'delivered',
    'completed',
    'cancelled'
  ];

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA500); // Orange
      case 'processing':
        return const Color(0xFF2196F3); // Blue
      case 'shipped':
        return const Color(0xFF673AB7); // Deep Purple
      case 'delivered':
        return const Color(0xFF4CAF50); // Green
      case 'completed':
        return const Color(0xFF2E7D32); // Darker Green
      case 'cancelled':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }
}
