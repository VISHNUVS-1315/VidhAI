import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:vidhai/data/models/notification_model.dart';
import 'package:vidhai/services/weather_service.dart';
import 'package:vidhai/services/notification/local_notification_engine.dart';
import 'package:vidhai/services/notification/notification_history_store.dart';
import 'package:vidhai/services/notification/notification_logic.dart';
import 'package:vidhai/services/notification/notification_settings_service.dart';
import 'package:vidhai/services/notification/notification_text.dart';

const _weatherTaskName = 'vidhai_weather_check';
const _weatherUniqueName = 'vidhai_weather_periodic';

/// WorkManager callback dispatcher — must be a top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case _weatherTaskName:
        await _runWeatherCheck();
        return true;
      default:
        return false;
    }
  });
}

Future<void> _runWeatherCheck() async {
  final prefs = await SharedPreferences.getInstance();

  final settingsOk = await NotificationSettingsService().isEnabled('weather');
  if (!settingsOk) return;

  final farmsRaw = prefs.getString('cached_farms');
  if (farmsRaw == null) return;

  List<Map<String, dynamic>> farms;
  try {
    farms = (json.decode(farmsRaw) as List)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  } catch (_) {
    return;
  }

  if (farms.isEmpty) return;

  final weatherService = WeatherService();

  final prevSig = prefs.getString('notif_weather_last_signature');
  final prevTimeStr = prefs.getString('notif_weather_last_time');
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

    final weather =
        await weatherService.getWeather(lat, lng, farmId: 'wm_wx_$i');
    if (weather == null) continue;

    final sig = NotificationLogic.weatherAlertSignature(weather, now, thresholds);
    if (sig == null) {
      continue;
    }
    if (!NotificationLogic.shouldNotifyWeather(
      previousSignature: prevSig,
      previousTime: prevTime,
      newSignature: sig,
      now: now,
      thresholds: thresholds,
    )) {
      continue;
    }

    final (title, body) = _weatherAlertText(sig);
    if (title == null) continue;

    final farmName = farm['farmName'] ?? 'Farm';
    final notifId = NotificationLogic.stableId('weather_bg_${i}_${now.millisecondsSinceEpoch}');
    final notification = NotificationModel(
      id: 'weather_bg_${i}_${now.millisecondsSinceEpoch}',
      title: title,
      message: '$body - $farmName',
      category: NotificationCategories.weather,
      createdAt: now,
      deepLink: '/main_shell',
      data: {'signature': sig, 'farmIndex': i, 'background': true},
    );

    await NotificationHistoryStore.instance.add(notification);
    await LocalNotificationEngine.instance.show(
      id: notifId,
      title: title,
      body: '$body - $farmName',
      category: NotificationCategories.weather,
      payload: '/main_shell',
    );

    await prefs.setString('notif_weather_last_signature', sig);
    await prefs.setString('notif_weather_last_time', now.toIso8601String());
    break; // One alert per cycle.
  }
}

(String?, String?) _weatherAlertText(String? sig) {
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

/// Register the hourly weather check. Call once at app startup.
Future<void> registerWeatherWorker() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _weatherUniqueName,
    _weatherTaskName,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 15),
  );
}
