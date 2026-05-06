// lib/features/orders/order_model.dart
// Shim file to re-export the canonical OrderModel to avoid dual-class confusion.

export 'package:swipify/features/orders/model/order_model.dart';
import 'package:swipify/features/orders/model/order_model.dart';

typedef Order = OrderModel;
typedef OrderItem = OrderItemModel;
