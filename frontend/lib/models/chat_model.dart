import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final String buyerId;
  final String sellerId;
  final String? productId;
  final String? productName;
  final String? productImage;
  final String? orderId;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final List<String> participants;
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final String buyerName;
  final String sellerName;

  ChatModel({
    required this.chatId,
    required this.buyerId,
    required this.sellerId,
    this.productId,
    this.productName,
    this.productImage,
    this.orderId,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.participants,
    required this.unreadCount,
    required this.createdAt,
    required this.buyerName,
    required this.sellerName,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      chatId: data['chat_id'] ?? '',
      buyerId: data['buyer_id'] ?? '',
      sellerId: data['seller_id'] ?? '',
      productId: data['product_id'],
      productName: data['product_name'],
      productImage: data['product_image'],
      orderId: data['order_id'],
      lastMessage: data['last_message'] ?? '',
      lastMessageTime: (data['last_message_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSenderId: data['last_sender_id'] ?? '',
      participants: List<String>.from(data['participants'] ?? []),
      unreadCount: Map<String, int>.from(data['unread_count'] ?? {}),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      buyerName: data['buyer_name'] ?? 'Unknown User',
      sellerName: data['seller_name'] ?? 'Unknown Store',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chat_id': chatId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'product_id': productId,
      'product_name': productName,
      'product_image': productImage,
      'order_id': orderId,
      'last_message': lastMessage,
      'last_message_time': FieldValue.serverTimestamp(),
      'last_sender_id': lastSenderId,
      'participants': participants,
      'unread_count': unreadCount,
      'created_at': createdAt,
      'buyer_name': buyerName,
      'seller_name': sellerName,
    };
  }
}
