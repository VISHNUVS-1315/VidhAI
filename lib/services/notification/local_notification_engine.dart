import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/core/routing/app_navigator.dart';
import 'package:vidhai/services/notification/notification_logic.dart';

/// Thin, guarded wrapper around flutter_local_notifications. All methods are
/// safe to call in test environments (plugin missing -> logged and skipped);
/// the rest of the app never touches the plugin directly.
class LocalNotificationEngine {
  LocalNotificationEngine._();
  static final LocalNotificationEngine instance = LocalNotificationEngine._();

  static const _permissionPromptedKey = 'notif_permission_prompted';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _pluginAvailable = false;
  bool _timezoneReady = false;

  bool get initialized => _initialized;

  /// Initializes the plugin, creates Android channels and checks whether the
  /// app was opened from a notification tap. Idempotent.
  Future<void> initialize({bool requestPermission = true}) async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      await _setDeviceTimezone();
      _timezoneReady = true;
    } catch (e) {
      debugPrint('timezone init failed: $e');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    try {
      final ok = await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
      _pluginAvailable = ok ?? false;
    } catch (e) {
      debugPrint('flutter_local_notifications unavailable: $e');
      _pluginAvailable = false;
    }

    if (_pluginAvailable) {
      await _createChannels();
    }

    _initialized = true;

    if (requestPermission) {
      await requestPermissionIfNeeded();
    }

    await _handleInitialLaunch();
  }

  Future<void> _setDeviceTimezone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(name);
      tz.setLocalLocation(location);
    } catch (_) {
      // Keep tz.local default when the platform plugin is unavailable.
    }
  }

  Future<void> _createChannels() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        NotificationChannels.tasks,
        'Farm Tasks',
        description: 'Reminders for your farm tasks',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotificationChannels.weather,
        'Weather Alerts',
        description: 'Weather alerts for your farm locations',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotificationChannels.updates,
        'VidhAI Updates',
        description: 'Recommendations and app updates',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotificationChannels.welcome,
        'Welcome',
        description: 'Welcome notifications',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        NotificationChannels.market,
        'Market Updates',
        description: 'Market price updates',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        NotificationChannels.default_,
        'General',
        description: 'General VidhAI notifications',
        importance: Importance.high,
      ),
    ];

    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  /// Requests POST_NOTIFICATIONS permission only once per install after the
  /// user has already answered. Safe to call on every launch.
  Future<bool> requestPermissionIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_permissionPromptedKey) == true) {
      return (await areNotificationsEnabled()) ?? false;
    }

    if (!_pluginAvailable) return false;

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    try {
      final result = await android.requestNotificationsPermission();
      await prefs.setBool(_permissionPromptedKey, true);
      return result ?? false;
    } catch (e) {
      debugPrint('notification permission request failed: $e');
      return false;
    }
  }

  Future<bool?> areNotificationsEnabled() async {
    if (!_pluginAvailable) return false;
    try {
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Shows an immediate heads-up/system notification.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String category,
    String? payload,
  }) async {
    if (!_pluginAvailable) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationChannels.channelFor(category),
            _channelNameFor(category),
            importance: Importance.high,
            priority: Priority.high,
            category: _androidCategoryFor(category),
            styleInformation: const DefaultStyleInformation(true, true),
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('show notification failed: $e');
    }
  }

  /// Cancels a notification by stable id.
  Future<void> cancel(int id) async {
    if (!_pluginAvailable) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('cancel notification $id failed: $e');
    }
  }

  /// Schedules a notification at [when] (device-local timezone).
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required String category,
    required DateTime when,
    String? payload,
  }) async {
    if (!_pluginAvailable) return;
    if (!_timezoneReady) return;
    try {
      final tzWhen = tz.TZDateTime.from(when, tz.local);
      if (tzWhen.isBefore(tz.TZDateTime.now(tz.local))) return;

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzWhen,
        NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationChannels.channelFor(category),
            _channelNameFor(category),
            importance: Importance.high,
            priority: Priority.high,
            category: _androidCategoryFor(category),
            styleInformation: const DefaultStyleInformation(true, true),
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('schedule notification $id failed: $e');
    }
  }

  String _channelNameFor(String category) {
    switch (NotificationChannels.channelFor(category)) {
      case NotificationChannels.tasks:
        return 'Farm Tasks';
      case NotificationChannels.weather:
        return 'Weather Alerts';
      case NotificationChannels.market:
        return 'Market Updates';
      case NotificationChannels.welcome:
        return 'Welcome';
      default:
        return 'VidhAI Updates';
    }
  }

  AndroidNotificationCategory? _androidCategoryFor(String category) {
    switch (category) {
      case NotificationCategories.task:
        return AndroidNotificationCategory.reminder;
      case NotificationCategories.weather:
        return AndroidNotificationCategory.alarm;
      case NotificationCategories.market:
        return AndroidNotificationCategory.event;
      case NotificationCategories.welcome:
        return AndroidNotificationCategory.status;
      default:
        return AndroidNotificationCategory.reminder;
    }
  }

  void _onDidReceiveNotificationResponse(
      NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    // Let the navigator mount before pushing the deep link.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    AppNavigator.pushNamed(payload);
  }

  Future<void> _handleInitialLaunch() async {
    if (!_pluginAvailable) return;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (response == null) return;
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      AppNavigator.pushNamed(payload);
    } catch (e) {
      debugPrint('initial launch notification handling failed: $e');
    }
  }
}