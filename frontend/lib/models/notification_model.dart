// lib/models/notification_model.dart
// Data model for a Notification fetched from the Swipify backend API.
// Fields follow the user-requested Firestore structure.

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

  /// Parse a NotificationModel from a JSON map (API response).
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'GENERAL',
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      createdAt: json['created_at'] ?? json['createdAt'],
    );
  }
}
