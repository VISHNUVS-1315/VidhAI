import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/locale/locale.dart';

/// Resolves notification titles/messages in the currently selected app
/// language. English and Tamil are fully translated; other languages cleanly
/// fall back to English through the same dictionary the UI uses.
class NotificationText {
  NotificationText._();

  static Future<String> _language() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('selected_language') ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  static String lookup(String key, [Map<String, String> params = const {}]) {
    final code = _activeLanguage;
    var value =
        AppLocalizations.rawLookup(code, key) ?? AppLocalizations.rawLookup('en', key) ?? '';
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  /// Cached active language set by [useLanguage].
  static String _activeLanguage = 'en';

  /// Called on app startup to pin the active language for background threads.
  static Future<void> useLanguage([String? code]) async {
    _activeLanguage = code ?? await _language();
  }

  static String get welcomeTitle =>
      lookup('notif_welcome_title');
  static String get welcomeMessage =>
      lookup('notif_welcome_message');

  static String get todoUpdatedTitle =>
      lookup('notif_todo_updated_title');
  static String todoUpdatedMessage(int count, String farm) =>
      lookup('notif_todo_updated_message', {'count': '$count', 'farm': farm});

  static String get taskReminderTitle =>
      lookup('notif_task_reminder_title');

  static String get weatherRainTitle => lookup('notif_weather_rain_title');
  static String get weatherRainMessage => lookup('notif_weather_rain_message');
  static String get weatherHeavyRainTitle =>
      lookup('notif_weather_heavy_rain_title');
  static String get weatherHeavyRainMessage =>
      lookup('notif_weather_heavy_rain_message');
  static String get weatherHeatTitle => lookup('notif_weather_heat_title');
  static String get weatherHeatMessage => lookup('notif_weather_heat_message');
  static String get weatherWindTitle => lookup('notif_weather_wind_title');
  static String get weatherWindMessage => lookup('notif_weather_wind_message');
  static String get weatherHumidityTitle =>
      lookup('notif_weather_humidity_title');
  static String get weatherHumidityMessage =>
      lookup('notif_weather_humidity_message');

  static String get marketUpdateTitle => lookup('notif_market_update_title');
  static String marketUpdateMessage(String commodity, String price) =>
      lookup('notif_market_update_message',
          {'commodity': commodity, 'price': price});

  // Settings screen labels.
  static String get settingsTitle => lookup('notif_settings_title');
  static String get settingsTaskReminders => lookup('notif_settings_tasks');
  static String get settingsWeatherAlerts => lookup('notif_settings_weather');
  static String get settingsMarketUpdates => lookup('notif_settings_market');
  static String get settingsGeneral => lookup('notif_settings_general');
}