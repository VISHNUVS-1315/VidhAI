import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/notification_model.dart';
import 'package:vidhai/services/task_service.dart';
import 'package:vidhai/services/weather_service.dart';
import 'package:vidhai/services/notification/local_notification_engine.dart';
import 'package:vidhai/services/notification/notification_history_store.dart';
import 'package:vidhai/services/notification/notification_logic.dart';
import 'package:vidhai/services/notification/notification_settings_service.dart';
import 'package:vidhai/services/notification/notification_text.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WeatherService _weatherService = WeatherService();
  final LocalNotificationEngine _engine = LocalNotificationEngine.instance;
  final NotificationSettingsService _settings = NotificationSettingsService();
  final NotificationHistoryStore _store = NotificationHistoryStore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  bool _initialized = false;

  // ------------------------------------------------------------------ init
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _engine.initialize(requestPermission: true);

    await _requestFcmPermission();
    await _getToken();
    _listenTokenRefresh();
    _setupForegroundHandler();
  }

  // --------------------------------------------------------------- FCM setup
  Future<void> _requestFcmPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: false,
      );
    } catch (_) {}
  }

  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) await _saveTokenToFirestore(_fcmToken!);
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

  // -------------------------------------------------------- foreground handler
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = _messageToNotification(message);
    _store.add(notification);
    final settingsCategory = notification.category == NotificationCategories.task
        ? NotificationCategories.task
        : notification.category == NotificationCategories.weather
            ? NotificationCategories.weather
            : notification.category == NotificationCategories.market
                ? NotificationCategories.market
                : null;

    _settings.isEnabled(settingsCategory ?? notification.category).then((ok) {
      if (!ok) return;
      _engine.show(
        id: _stableNotifId(notification.id),
        title: notification.title,
        body: notification.message,
        category: notification.category,
        payload: NotificationLogic.deepLinkFor(
            notification.deepLink, notification.category),
      );
    });
  }

  NotificationModel _messageToNotification(RemoteMessage message) {
    final data = message.data;
    return NotificationModel(
      id: message.messageId ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? data['title'] ?? 'VidhAI',
      message: message.notification?.body ?? data['body'] ?? '',
      category: data['category'] ?? 'alert',
      createdAt: DateTime.now(),
      data: data,
      deepLink: data['deepLink'],
    );
  }

  // ------------------------------------------------- generic show API (public)
  /// Show any notification as a real Android heads-up notification, store it
  /// in the history, and return the created model.
  Future<NotificationModel> showAppNotification({
    required String title,
    required String body,
    required String category,
    String? deepLink,
    Map<String, dynamic>? data,
  }) async {
    final id = 'app_${DateTime.now().millisecondsSinceEpoch}';
    final route = NotificationLogic.deepLinkFor(deepLink, category);
    final notification = NotificationModel(
      id: id,
      title: title,
      message: body,
      category: category,
      createdAt: DateTime.now(),
      data: data,
      deepLink: route,
    );

    final ok = await _settings.isEnabled(category);
    await _store.add(notification);
    if (ok) {
      await _engine.show(
        id: _stableNotifId(id),
        title: title,
        body: body,
        category: category,
        payload: route,
      );
    }
    await _syncToFirestore(notification);
    return notification;
  }

  bool _startupSyncDone = false;

  /// Non-blocking startup sync after sign-in: welcome, todo fingerprint,
  /// task reminder scheduling and a weather pass. Never blocks UI.
  Future<void> syncAfterSignIn() async {
    if (_startupSyncDone) return;
    _startupSyncDone = true;

    await NotificationText.useLanguage();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await welcomeOnFirstSignIn(uid);

      final tasks = await TaskService().loadTasks();
      if (tasks.isNotEmpty) {
        await scheduleTaskReminders(tasks);
        await syncTodoFingerprint(tasks);
      }

      final farms = await _loadCachedFarmsForWeather();
      if (farms.isNotEmpty) {
        await checkWeatherAlerts(farms);
      }
    } catch (_) {
      // Sync is opportunistic; never crash startup on notification errors.
    }
  }

  Future<List<Map<String, dynamic>>> _loadCachedFarmsForWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_farms');
      if (raw == null) return [];
      return (json.decode(raw) as List)
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // -------------------------------------------------- welcome once per user
  Future<void> welcomeOnFirstSignIn(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'welcome_shown_$uid';
    if (prefs.getBool(key) == true) return;

    final ok = await _settings.isEnabled(NotificationCategories.welcome);
    await _store.add(NotificationModel(
      id: 'welcome_$uid',
      title: NotificationText.welcomeTitle,
      message: NotificationText.welcomeMessage,
      category: NotificationCategories.welcome,
      createdAt: DateTime.now(),
      deepLink: '/main_shell',
    ));
    if (ok) {
      await _engine.show(
        id: _stableNotifId('welcome_$uid'),
        title: NotificationText.welcomeTitle,
        body: NotificationText.welcomeMessage,
        category: NotificationCategories.welcome,
        payload: '/main_shell',
      );
    }
    await prefs.setBool(key, true);
  }

  // --------------------------------------------------- todo fingerprint sync
  static const _todoFpKey = 'notif_todo_fingerprint';

  /// Emit a "todo updated" notification only when the task list has changed
  /// meaningfully.
  Future<void> syncTodoFingerprint(List<FarmTask> tasks) async {
    if (tasks.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final newFp = NotificationLogic.taskListFingerprint(tasks);
    final oldFp = prefs.getString(_todoFpKey);
    if (newFp == oldFp) return;

    await prefs.setString(_todoFpKey, newFp);

    final pending = tasks.where((t) => !t.completed).toList();
    if (pending.isEmpty) return;

    final farmNames = <String>{
      for (final t in pending) t.farmName,
    };
    final farmLabel = farmNames.first;

    final ok = await _settings.isEnabled(NotificationCategories.task);
    final notification = NotificationModel(
      id: 'todo_update_${DateTime.now().millisecondsSinceEpoch}',
      title: NotificationText.todoUpdatedTitle,
      message: NotificationText.todoUpdatedMessage(pending.length, farmLabel),
      category: NotificationCategories.task,
      createdAt: DateTime.now(),
      deepLink: '/tasks',
    );
    await _store.add(notification);
    if (ok) {
      await _engine.show(
        id: _stableNotifId(notification.id),
        title: notification.title,
        body: notification.message,
        category: notification.category,
        payload: '/tasks',
      );
    }
  }

  // ------------------------------------------------- task reminder scheduling
  static const _reminderStateKey = 'notif_task_reminder_state';

  /// Reconcile individual per-task scheduled reminders: cancel completed/
  /// deleted tasks, schedule or reschedule remaining ones using stable IDs.
  Future<void> scheduleTaskReminders(List<FarmTask> tasks) async {
    final ok = await _settings.isEnabled(NotificationCategories.task);
    if (!ok) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderStateKey) ?? '{}';
    var prev = <String, dynamic>{};
    try {
      prev = Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {
      prev = {};
    }

    final currentIds = <String>{};

    for (final task in tasks) {
      if (task.completed || task.scheduledTime == null) continue;
      final parsed = NotificationLogic.parseScheduleTime(task.scheduledTime);
      if (parsed == null) continue;

      final (hour, minute) = parsed;
      final when =
          NotificationLogic.nextOccurrence(DateTime.now(), hour, minute);
      final seed =
          'task_${task.farmIndex}_${task.scheduledTime ?? ''}_${task.title}';
      final notifId = NotificationLogic.stableId(seed);
      final idStr = '$notifId';

      currentIds.add(idStr);

      final prevWhen = prev[idStr];
      final prevWhenDt =
          prevWhen is String ? DateTime.tryParse(prevWhen) : null;
      final shouldReschedule = prevWhen == null ||
          prevWhenDt == null ||
          prevWhenDt.isBefore(when.subtract(const Duration(minutes: 2))) ||
          prevWhenDt.isAfter(when.add(const Duration(minutes: 2)));

      if (!shouldReschedule) continue;

      await _engine.cancel(notifId);
      await _engine.schedule(
        id: notifId,
        title: NotificationText.taskReminderTitle,
        body: task.title,
        category: NotificationCategories.task,
        when: when,
        payload: '/tasks',
      );
      prev[idStr] = when.toIso8601String();
    }

    // Cancel reminders for tasks no longer present or completed/deleted.
    for (final key in prev.keys.toList()) {
      if (!currentIds.contains(key)) {
        final id = int.tryParse(key);
        if (id != null) await _engine.cancel(id);
        prev.remove(key);
      }
    }

    await prefs.setString(_reminderStateKey, json.encode(prev));
  }

  /// Cancel a specific task reminder (call on completion/deletion).
  Future<void> cancelTaskReminder(FarmTask task) async {
    final seed =
        'task_${task.farmIndex}_${task.scheduledTime ?? ''}_${task.title}';
    final notifId = NotificationLogic.stableId(seed);
    await _engine.cancel(notifId);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reminderStateKey) ?? '{}';
    var prev = <String, dynamic>{};
    try {
      prev = Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {
      prev = {};
    }
    prev.remove('$notifId');
    await prefs.setString(_reminderStateKey, json.encode(prev));
  }

  // ------------------------------------------------------------ weather alert
  static const _weatherSigKey = 'notif_weather_last_signature';
  static const _weatherTimeKey = 'notif_weather_last_time';

  /// Check weather for all farms with valid locations, emit an alert
  /// notification when threshold is breached and dedup allows it.
  Future<void> checkWeatherAlerts(List<Map<String, dynamic>> farms) async {
    final ok = await _settings.isEnabled(NotificationCategories.weather);
    if (!ok) return;

    final prefs = await SharedPreferences.getInstance();
    final prevSig = prefs.getString(_weatherSigKey);
    final prevTimeStr = prefs.getString(_weatherTimeKey);
    final prevTime = prevTimeStr != null ? DateTime.tryParse(prevTimeStr) : null;
    final now = DateTime.now();
    const thresholds = WeatherAlertThresholds();

    for (var i = 0; i < farms.length; i++) {
      final farm = farms[i];
      final loc = farm['farmLocation'];
      if (loc == null) continue;
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final weather = await _weatherService.getWeather(lat, lng, farmId: 'notif_wx_$i');
      if (weather == null) continue;

      final sig = NotificationLogic.weatherAlertSignature(weather, now, thresholds);
      if (sig == null) continue;
      if (!NotificationLogic.shouldNotifyWeather(
        previousSignature: prevSig,
        previousTime: prevTime,
        newSignature: sig,
        now: now,
        thresholds: thresholds,
      )) {
        continue;
      }

      final (title, body) = _weatherAlertText(sig, weather);
      if (title == null) continue;

      final farmName = farm['farmName'] ?? 'Farm';
      final notification = NotificationModel(
        id: 'weather_${i}_${now.millisecondsSinceEpoch}',
        title: title,
        message: '$body - $farmName',
        category: NotificationCategories.weather,
        createdAt: now,
        deepLink: '/main_shell',
        data: {'signature': sig, 'farmIndex': i},
      );
      await _store.add(notification);
      await _engine.show(
        id: _stableNotifId(notification.id),
        title: notification.title,
        body: notification.message,
        category: notification.category,
        payload: '/main_shell',
      );

      await prefs.setString(_weatherSigKey, sig);
      await prefs.setString(_weatherTimeKey, now.toIso8601String());
      break; // One alert per check cycle to avoid spam.
    }
  }

  (String?, String?) _weatherAlertText(String? sig, WeatherData weather) {
    if (sig == null) return (null, null);
    final parts = sig.split('_').first.split(',');
    if (parts.contains('heavy_rain')) {
      return (
        NotificationText.weatherHeavyRainTitle,
        NotificationText.weatherHeavyRainMessage,
      );
    }
    if (parts.contains('rain')) {
      return (
        NotificationText.weatherRainTitle,
        NotificationText.weatherRainMessage,
      );
    }
    if (parts.contains('heat')) {
      return (
        NotificationText.weatherHeatTitle,
        NotificationText.weatherHeatMessage,
      );
    }
    if (parts.contains('wind')) {
      return (
        NotificationText.weatherWindTitle,
        NotificationText.weatherWindMessage,
      );
    }
    if (parts.contains('humidity')) {
      return (
        NotificationText.weatherHumidityTitle,
        NotificationText.weatherHumidityMessage,
      );
    }
    return (null, null);
  }

  // -------------------------------------------------- Firestore sync helpers
  Future<void> _syncToFirestore(NotificationModel notification) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
    } catch (_) {}
  }

  // ------------------------------------------------- history API (UI compat)
  Future<List<NotificationModel>> loadNotifications() => _store.load();
  Future<void> markAsRead(String id) => _store.markAsRead(id);
  Future<void> markAllAsRead() => _store.markAllAsRead();
  Future<void> deleteNotification(String id) => _store.delete(id);
  Future<int> getUnreadCount() => _store.unreadCount();

  // ----------------------------------------------------------------- deep link
  static String? getDeepLinkRoute(String? deepLink) {
    if (deepLink == null || deepLink == '') return null;
    return NotificationLogic.deepLinkFor(deepLink, 'alert');
  }

  // ----------------------------------------------------------------- helpers
  int _stableNotifId(String seed) => NotificationLogic.stableId(seed);
}

// ---- Top-level FCM background handler (must be outside any class) ----------

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    final notification = NotificationModel(
      id: message.messageId ??
          'bg_${DateTime.now().millisecondsSinceEpoch}',
      title: message.notification?.title ??
          message.data['title'] ??
          'VidhAI',
      message: message.notification?.body ?? message.data['body'] ?? '',
      category: message.data['category'] ?? 'alert',
      createdAt: DateTime.now(),
      data: message.data,
      deepLink: message.data['deepLink'],
    );
    await NotificationHistoryStore.instance.add(notification);
  } catch (_) {}
}
