import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/services/notification/notification_logic.dart';

/// Persisted per-category notification toggles (single source of truth for
/// what the user opted in/out of). Uses SharedPreferences so it is testable.
class NotificationSettingsService {
  static final NotificationSettingsService _instance =
      NotificationSettingsService._();
  factory NotificationSettingsService() => _instance;
  NotificationSettingsService._();

  static const _taskKey = 'notif_task_reminders';
  static const _weatherKey = 'notif_weather_alerts';
  static const _marketKey = 'notif_market_updates';
  static const _generalKey = 'notif_general_notifications';

  /// Whether a category is currently enabled (default: ON).
  Future<bool> isEnabled(String category) async {
    final prefs = await SharedPreferences.getInstance();
    switch (category) {
      case NotificationCategories.task:
        return prefs.getBool(_taskKey) ?? true;
      case NotificationCategories.weather:
        return prefs.getBool(_weatherKey) ?? true;
      case NotificationCategories.market:
        return prefs.getBool(_marketKey) ?? true;
      default:
        return prefs.getBool(_generalKey) ?? true;
    }
  }

  Future<void> setEnabled(String category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    switch (category) {
      case NotificationCategories.task:
        await prefs.setBool(_taskKey, enabled);
        break;
      case NotificationCategories.weather:
        await prefs.setBool(_weatherKey, enabled);
        break;
      case NotificationCategories.market:
        await prefs.setBool(_marketKey, enabled);
        break;
      default:
        await prefs.setBool(_generalKey, enabled);
        break;
    }
  }

  Future<bool> taskRemindersEnabled() => isEnabled('task');
  Future<bool> weatherAlertsEnabled() => isEnabled('weather');
  Future<bool> marketUpdatesEnabled() => isEnabled('market');
  Future<bool> generalNotificationsEnabled() => isEnabled('default');

  Future<void> setTaskReminders(bool v) => setEnabled('task', v);
  Future<void> setWeatherAlerts(bool v) => setEnabled('weather', v);
  Future<void> setMarketUpdates(bool v) => setEnabled('market', v);
  Future<void> setGeneralNotifications(bool v) => setEnabled('default', v);
}