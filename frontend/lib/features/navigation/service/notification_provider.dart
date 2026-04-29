// lib/features/navigation/service/notification_provider.dart
// Notification Provider for managing user notifications.
// Restored after accidental deletion during modular migration.

import 'package:flutter/material.dart';
import 'package:swipify/models/notification_model.dart';
import 'package:swipify/services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _userId;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  /// Initialize the provider with a user ID and load notifications.
  void init(String? uid) {
    if (uid == _userId) return;
    _userId = uid;
    
    // Use Future.microtask to avoid calling notifyListeners() during build
    Future.microtask(() {
      if (_userId != null) {
        loadNotifications();
      } else {
        _notifications = [];
        _unreadCount = 0;
        notifyListeners();
      }
    });
  }

  /// Fetch notifications from the API.
  Future<void> loadNotifications() async {
    if (_userId == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.getNotifications(_userId!);
      // Use cast carefully
      final notifsList = data['notifications'];
      if (notifsList is List<NotificationModel>) {
        _notifications = notifsList;
      } else if (notifsList is List) {
        _notifications = notifsList.whereType<NotificationModel>().toList();
      }
      
      _unreadCount = (data['unreadCount'] ?? 0) as int;
    } catch (e) {
      debugPrint('[NOTIF] Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark all unread notifications as read.
  Future<void> markAllAsRead() async {
    if (_userId == null || _unreadCount == 0) return;

    final unreadIds = _notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    if (unreadIds.isEmpty) return;

    try {
      await ApiService.markNotificationsRead(unreadIds);
      // Optimistic update
      _notifications = _notifications.map((n) {
        if (!n.isRead) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('[NOTIF] Error marking all as read: $e');
    }
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;

    final notif = _notifications.firstWhere((n) => n.id == notificationId, 
      orElse: () => const NotificationModel(id: '', userId: '', title: '', message: '', type: '', isRead: true));
    
    if (notif.id.isEmpty || notif.isRead) return;

    try {
      await ApiService.markNotificationsRead([notificationId]);
      // Optimistic update
      _notifications = _notifications.map((n) {
        if (n.id == notificationId) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      _unreadCount = (_unreadCount > 0) ? _unreadCount - 1 : 0;
      notifyListeners();
    } catch (e) {
      debugPrint('[NOTIF] Error marking notification read: $e');
    }
  }
}
