import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String message;
  final String type; // 'text', 'image', 'video'
  final String? mediaUrl;
  final DateTime createdAt;
  final String status; // 'sent', 'delivered', 'seen'

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.type,
    this.mediaUrl,
    required this.createdAt,
    required this.status,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      messageId: doc.id,
      senderId: data['sender_id'] ?? '',
      receiverId: data['receiver_id'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'text',
      mediaUrl: data['media_url'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'sent',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'type': type,
      'media_url': mediaUrl,
      'created_at': FieldValue.serverTimestamp(),
      'status': status,
    };
  }
}
