import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    await _requestPermission();
    await _getToken();
    _listenTokenRefresh();
    _setupForegroundHandler();
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
      provisional: false,
      criticalAlert: false,
    );
    // Permission states: authorized, denied, provisional, notDetermined
  }

  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
      }
    } catch (_) {}
  }

  void _listenTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveTokenToFirestore(newToken);
    });
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await _firestore.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = _messageToNotification(message);
    _saveNotificationLocally(notification);
    _showLocalNotification(notification);
  }

  static void _showLocalNotification(NotificationModel notification) async {
    // Local notification display is handled by the notification service
    // The actual tray notification is handled via Android NotificationChannel
    // and Firebase's built-in system notification for background/terminated
  }

  NotificationModel _messageToNotification(RemoteMessage message) {
    final data = message.data;
    return NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? data['title'] ?? 'VidhAI',
      message: message.notification?.body ?? data['body'] ?? '',
      category: data['category'] ?? 'alert',
      createdAt: DateTime.now(),
      data: data,
      deepLink: data['deepLink'],
    );
  }

  Future<void> _saveNotificationLocally(NotificationModel notification) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = json.decode(existing) as List;
    list.insert(0, notification.toMap());
    if (list.length > 200) list.removeLast();
    await prefs.setString('notification_history', json.encode(list));
  }

  // Remote persistence via Firestore
  Future<void> saveNotificationToFirestore(NotificationModel notification) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await _firestore
          .collection('users').doc(uid)
          .collection('notifications').doc(notification.id)
          .set(notification.toMap());
    } catch (_) {}
  }

  Future<List<NotificationModel>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = json.decode(existing) as List;
    return list.map((m) => NotificationModel.fromMap(m)).toList();
  }

  Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = (json.decode(existing) as List).map((m) => Map<String, dynamic>.from(m)).toList();
    for (var item in list) {
      if (item['id'] == id) {
        item['isRead'] = true;
        break;
      }
    }
    await prefs.setString('notification_history', json.encode(list));
  }

  Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = (json.decode(existing) as List).map((m) => Map<String, dynamic>.from(m)).toList();
    for (var item in list) {
      item['isRead'] = true;
    }
    await prefs.setString('notification_history', json.encode(list));
  }

  Future<void> deleteNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = (json.decode(existing) as List).map((m) => Map<String, dynamic>.from(m)).toList();
    list.removeWhere((item) => item['id'] == id);
    await prefs.setString('notification_history', json.encode(list));
  }

  Future<int> getUnreadCount() async {
    final notifications = await loadNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  // Background message handler - must be top-level function
  static Future<void> onBackgroundMessage(RemoteMessage message) async {
    // Background messages are handled automatically by FCM
    // Data is persisted when the user opens the app
  }

  // Deep link handling
  static String? getDeepLinkRoute(String? deepLink) {
    if (deepLink == null || deepLink.isEmpty) return null;
    if (deepLink.startsWith('/weather')) return '/main_shell';
    if (deepLink.startsWith('/tasks')) return '/main_shell';
    if (deepLink.startsWith('/farm')) return '/main_shell';
    return '/main_shell';
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message handler
}
