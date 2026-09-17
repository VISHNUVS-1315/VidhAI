import 'dart:convert';
import 'package:vidhai/data/models/notification_model.dart';
import 'package:vidhai/services/task_service.dart';
import 'package:vidhai/services/weather_service.dart';

/// Notification constants shared across the app.
class NotificationCategories {
  static const welcome = 'welcome';
  static const task = 'task';
  static const weather = 'weather';
  static const market = 'market';
  static const recommendation = 'recommendation';
  static const alert = 'alert';
  static const community = 'community';

  static const List<String> all = [
    welcome,
    task,
    weather,
    market,
    recommendation,
    alert,
    community,
  ];

  static bool isValid(String category) => all.contains(category);
}

/// Notification channel ids (Android).
class NotificationChannels {
  static const tasks = 'vidhai_tasks';
  static const weather = 'vidhai_weather';
  static const updates = 'vidhai_updates';
  static const welcome = 'vidhai_welcome';
  static const market = 'vidhai_market';
  static const community = 'vidhai_community';
  static const default_ = 'vidhai_default';

  static String channelFor(String category) {
    switch (category) {
      case NotificationCategories.welcome:
        return welcome;
      case NotificationCategories.task:
        return tasks;
      case NotificationCategories.weather:
        return weather;
      case NotificationCategories.market:
        return market;
      case NotificationCategories.community:
        return community;
      default:
        return updates;
    }
  }
}

/// Pure, dependency-free notification helpers (testable without plugins).
class NotificationLogic {
  NotificationLogic._();

  /// Deep link route for a notification category (fallback home shell).
  static String deepLinkFor(String? deepLink, String category) {
    if (deepLink != null && deepLink.isNotEmpty) return deepLink;
    switch (category) {
      case NotificationCategories.welcome:
      case NotificationCategories.recommendation:
      case NotificationCategories.alert:
        return '/main_shell';
      case NotificationCategories.task:
        return '/tasks';
      case NotificationCategories.weather:
        return '/main_shell';
      case NotificationCategories.market:
        return '/market-prices';
      case NotificationCategories.community:
        return '/community';
      default:
        return '/main_shell';
    }
  }

  /// Parses "8:00 AM", "12:00 PM", "6:30 PM", "06:00" into hour/minute.
  /// Returns null when unparseable.
  static (int, int)? parseScheduleTime(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty) return null;

    final cleaned = text.toUpperCase().replaceAll(' ', ' ');
    final isPM = cleaned.contains('PM');
    final isAM = cleaned.contains('AM');
    var timePart = cleaned
        .replaceAll('PM', '')
        .replaceAll('AM', '')
        .trim();

    final parts = timePart.split(':');
    if (parts.isEmpty || parts.length > 2) return null;

    final hourRaw = int.tryParse(parts[0].trim());
    if (hourRaw == null || hourRaw < 0 || hourRaw > 23) return null;

    var hour = hourRaw;
    var minute = 0;
    if (parts.length == 2) {
      final minuteRaw = int.tryParse(parts[1].trim());
      if (minuteRaw == null || minuteRaw < 0 || minuteRaw > 59) return null;
      minute = minuteRaw;
    }

    if (isPM && hour < 12) hour += 12;
    if (isAM && hour == 12) hour = 0;

    // Accept military 24h values directly.
    if (!isAM && !isPM && hourRaw >= 0 && hourRaw <= 23) {
      hour = hourRaw;
    }

    return (hour, minute);
  }

  /// Next occurrence of (hour, minute) from [now]. If exactly at that time
  /// within a minute we consider it the current slot.
  static DateTime nextOccurrence(DateTime now, int hour, int minute) {
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (candidate.isBefore(now) ||
        candidate.difference(now).inMinutes < -1) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// A stable, deterministic non-negative int32 id from any string.
  static int stableId(String seed) {
    var hash = 0x811C9DC5;
    for (final code in utf8.encode(seed)) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// Stable id for a task reminder, derived from task content (farm + time +
  /// title) so regeneration of task ids (which are time-based) keeps the same
  /// reminder id and avoids duplicate schedules.
  static int taskReminderId(FarmTask task) {
    final seed =
        'task_${task.farmIndex}_${task.scheduledTime ?? ''}_${task.title}';
    return stableId(seed);
  }

  /// Fingerprint of a task list used to detect meaningful changes.
  static String taskListFingerprint(List<FarmTask> tasks) {
    final lines = tasks
        .map((t) =>
            '${t.farmIndex}|${t.title}|${t.scheduledTime ?? ''}|${t.completed}')
        .toList()
      ..sort();
    return sha256Hex(lines.join('\n'));
  }

  /// Fingerprint of task list keyed by farm name (uses per-farm grouping).
  static String taskListFingerprintByFarm(
      List<FarmTask> tasks, String farmName) {
    final farmTasks = tasks
        .where((t) => t.farmName == farmName)
        .map((t) =>
            '${t.farmIndex}|${t.title}|${t.scheduledTime ?? ''}|${t.completed}')
        .toList()
      ..sort();
    return sha256Hex(farmTasks.join('\n'));
  }

  /// sha256 hex helper (pure Dart, testable).
  static String sha256Hex(String input) {
    return _cyclone(input);
  }

  static String _cyclone(String input) {
    // FNV-1a 64-bit based fingerprint is stable across runs and platforms,
    // sufficient for dedup semantics (not a crypto hash).
    var hash = 0xcbf29ce484222325;
    for (final code in utf8.encode(input)) {
      hash ^= code;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Weather alert signature — a compact string describing currently active
  /// alert conditions and their severity bucket, used to deduplicate alerts.
  /// Returns null when no alert condition is active.
  static String? weatherAlertSignature(
    WeatherData weather,
    DateTime now,
    WeatherAlertThresholds thresholds,
  ) {
    final active = <String>[];
    final daily = weather.daily.isNotEmpty ? weather.daily.first : null;
    final rain = daily?.precipitationSum ?? weather.precipitation ?? 0;
    final humidity = weather.humidity;
    final temp = weather.temperature;
    final wind = weather.windSpeed;
    final windMax = daily?.windSpeedMax ?? wind;
    final weatherCode = weather.weatherCode;

    final rainNow = weather.precipitation ?? 0;
    final isHeavyRain = rainNow >= thresholds.heavyRainMm && rain >= thresholds.heavyRainMm;
    final isRain = rain >= thresholds.rainMm || rainNow >= thresholds.rainMm;
    final isThunderstorm = weatherCode >= 95;

    if (isHeavyRain || isThunderstorm) {
      active.add('heavy_rain');
    } else if (isRain) {
      active.add('rain');
    }
    if (temp >= thresholds.heatC) active.add('heat');
    if (windMax >= thresholds.windKmh) active.add('wind');
    if (humidity >= thresholds.humidityPct) active.add('humidity');

    if (active.isEmpty) return null;

    return '${active.join(',')}_${_bucket(rain)}_${_bucket(temp)}_${_bucket(humidity.toDouble())}_${_bucket(windMax)}';
  }

  static int _bucket(double value) => (value / 5).floor();

  /// Should a new weather notification be emitted given previous signature?
  static bool shouldNotifyWeather({
    required String? previousSignature,
    required DateTime? previousTime,
    required String? newSignature,
    required DateTime now,
    required WeatherAlertThresholds thresholds,
  }) {
    if (newSignature == null) return false;
    if (previousSignature == null) return true;
    if (previousSignature != newSignature) return true;
    if (previousTime == null) return true;
    return now.difference(previousTime).inMinutes >=
        thresholds.repeatIntervalMinutes;
  }
}

/// Threshold configuration for weather alerts.
class WeatherAlertThresholds {
  final double rainMm;
  final double heavyRainMm;
  final double heatC;
  final double windKmh;
  final int humidityPct;
  final int repeatIntervalMinutes;

  const WeatherAlertThresholds({
    this.rainMm = 5,
    this.heavyRainMm = 25,
    this.heatC = 38,
    this.windKmh = 40,
    this.humidityPct = 85,
    this.repeatIntervalMinutes = 360,
  });
}

/// Maps a NotificationModel category to its stable system manifestation.
class NotificationDeepLinkResolver {
  NotificationDeepLinkResolver._();

  static String? routeFor(NotificationModel notification) {
    final route = NotificationLogic.deepLinkFor(
      notification.deepLink,
      notification.category,
    );
    return route;
  }
}