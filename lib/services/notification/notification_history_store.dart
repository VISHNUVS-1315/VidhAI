import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/notification_model.dart';

/// Single source of truth for the in-app Notification Center history.
/// Persisted in SharedPreferences under `notification_history`, the same key
/// the existing UI reads, so no second history store exists.
class NotificationHistoryStore {
  NotificationHistoryStore._();
  static final NotificationHistoryStore instance =
      NotificationHistoryStore._();

  static const _historyKey = 'notification_history';
  static const _maxEntries = 200;

  Future<List<NotificationModel>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey) ?? '[]';
    try {
      final list = json.decode(raw) as List;
      return list
          .map((m) => NotificationModel.fromMap(
              Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Adds a notification, deduplicating by id (no duplicate history rows).
  Future<void> add(NotificationModel notification) async {
    final current = await load();
    current.removeWhere((n) => n.id == notification.id);
    current.insert(0, notification);
    if (current.length > _maxEntries) {
      current.removeRange(_maxEntries, current.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _historyKey, json.encode(current.map((n) => n.toMap()).toList()));
  }

  Future<void> markAsRead(String id) async {
    final current = await load();
    for (final n in current) {
      if (n.id == id) {
        final idx = current.indexOf(n);
        current[idx] = n.copyWith(isRead: true);
        break;
      }
    }
    await _persist(current);
  }

  Future<void> markAllAsRead() async {
    final current = await load();
    final updated = current.map((n) => n.copyWith(isRead: true)).toList();
    await _persist(updated);
  }

  Future<void> delete(String id) async {
    final current = await load();
    current.removeWhere((n) => n.id == id);
    await _persist(current);
  }

  Future<int> unreadCount() async {
    final current = await load();
    return current.where((n) => !n.isRead).length;
  }

  Future<void> _persist(List<NotificationModel> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _historyKey, json.encode(list.map((n) => n.toMap()).toList()));
  }

  // Backwards-compatible helpers kept for the existing Notification Center UI.
  Future<List<NotificationModel>> loadNotifications() => load();
  Future<void> saveNotification(NotificationModel n) => add(n);
  Future<void> markNotificationRead(String id) => markAsRead(id);
  Future<void> markAllNotificationsRead() => markAllAsRead();
  Future<void> deleteNotification(String id) => delete(id);
  Future<int> getUnreadCount() => unreadCount();
}