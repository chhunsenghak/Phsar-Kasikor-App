import 'package:flutter/material.dart';
import '../../services/api/notification_api.dart';
import '../../utils/phnom_penh_time.dart';
import 'base_app_state.dart';

mixin NotificationStateMixin on BaseAppState {
  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => _notifications;

  String _formatDateTimeTo12Hour(String? isoString) {
    final formatted = formatPhnomPenhDateTime(isoString);
    return formatted.isEmpty ? 'Just now' : formatted;
  }

  @override
  Future<void> addNotification(String title, String body) async {
    if (token != null && userProfile != null) {
      try {
        final userId = userProfile!['id'] ?? '';
        await NotificationApi.createNotification(
          token!,
          userId: userId,
          title: title,
          message: body,
        );
        await refreshNotifications();
      } catch (e) {
        debugPrint('Failed to save notification on backend: $e');
      }
      return;
    }
    _notifications.insert(0, {
      'id': DateTime.now().toString(),
      'title': title,
      'body': body,
      'time': _formatDateTimeTo12Hour(DateTime.now().toUtc().toIso8601String()),
      'isRead': false,
    });
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    if (token == null) return;
    try {
      final List<dynamic> backendNotifs = await NotificationApi.fetchNotifications(token!);
      _notifications.clear();
      for (var json in backendNotifs) {
        _notifications.add({
          'id': json['id'] ?? '',
          'title': json['title'] ?? '',
          'body': json['message'] ?? '',
          'time': _formatDateTimeTo12Hour(json['sent_at']?.toString()),
          'isRead': json['is_read'] ?? false,
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh notifications: $e');
    }
  }

  void markAllNotificationsRead() {
    for (var n in _notifications) {
      n['isRead'] = true;
      if (token != null) {
        try {
          NotificationApi.markNotificationAsRead(token!, n['id']);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n['id']?.toString() == id);
    notifyListeners();
    if (token != null) {
      NotificationApi.deleteNotification(token!, id).catchError((e) {
        debugPrint('Failed to soft delete notification on backend: $e');
        return <String, dynamic>{};
      });
    }
  }
}
