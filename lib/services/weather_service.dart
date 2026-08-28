import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherData {
  final double temperature;
  final double feelsLike;
  final int weatherCode;
  final String condition;
  final int humidity;
  final double windSpeed;
  final int windDirection;
  final double windGusts;
  final double pressure;
  final double? precipitation;
  final double? uvIndex;
  final DateTime timestamp;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;

  const WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.weatherCode,
    required this.condition,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.pressure,
    this.precipitation,
    this.uvIndex,
    required this.timestamp,
    this.hourly = const [],
    this.daily = const [],
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] ?? {};
    final hourly = json['hourly'] ?? {};
    final daily = json['daily'] ?? {};

    final hourlyList = <HourlyForecast>[];
    if (hourly['time'] != null) {
      final now = DateTime.now();
      for (var i = 0; i < (hourly['time'] as List).length && i < 24; i++) {
        final time = DateTime.tryParse(hourly['time'][i]);
        if (time != null && time.isAfter(now.subtract(const Duration(hours: 1)))) {
          hourlyList.add(HourlyForecast(
            time: time,
            temperature: (hourly['temperature_2m'][i] as num?)?.toDouble() ?? 0,
            weatherCode: hourly['weather_code'][i] ?? 0,
            precipitation: (hourly['precipitation'][i] as num?)?.toDouble() ?? 0,
          ));
        }
      }
    }

    final dailyList = <DailyForecast>[];
    if (daily['time'] != null) {
      for (var i = 0; i < (daily['time'] as List).length; i++) {
        dailyList.add(DailyForecast(
          date: DateTime.tryParse(daily['time'][i]) ?? DateTime.now(),
          maxTemp: (daily['temperature_2m_max'][i] as num?)?.toDouble() ?? 0,
          minTemp: (daily['temperature_2m_min'][i] as num?)?.toDouble() ?? 0,
          weatherCode: daily['weather_code'][i] ?? 0,
          precipitationSum:
              (daily['precipitation_sum'][i] as num?)?.toDouble() ?? 0,
          windSpeedMax:
              (daily['wind_speed_10m_max'][i] as num?)?.toDouble() ?? 0,
        ));
      }
    }

    final weatherCode = current['weather_code'] ?? 0;
    return WeatherData(
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      feelsLike:
          (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
      weatherCode: weatherCode,
      condition: _weatherCodeToCondition(weatherCode),
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      windSpeed:
          (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      windDirection:
          (current['wind_direction_10m'] as num?)?.toInt() ?? 0,
      windGusts:
          (current['wind_gusts_10m'] as num?)?.toDouble() ?? 0,
      pressure: (current['pressure_msl'] as num?)?.toDouble() ?? 0,
      precipitation:
          (current['precipitation'] as num?)?.toDouble(),
      timestamp: DateTime.now(),
      hourly: hourlyList,
      daily: dailyList,
    );
  }

  static String _weatherCodeToCondition(int code) {
    const conditions = {
      0: 'Clear sky',
      1: 'Mainly clear', 2: 'Partly cloudy', 3: 'Overcast',
      45: 'Fog', 48: 'Depositing rime fog',
      51: 'Light drizzle', 53: 'Moderate drizzle', 55: 'Dense drizzle',
      61: 'Slight rain', 63: 'Moderate rain', 65: 'Heavy rain',
      71: 'Slight snow', 73: 'Moderate snow', 75: 'Heavy snow',
      80: 'Slight rain showers', 81: 'Moderate rain showers', 82: 'Violent rain showers',
      85: 'Slight snow showers', 86: 'Heavy snow showers',
      95: 'Thunderstorm', 96: 'Thunderstorm with slight hail', 99: 'Thunderstorm with heavy hail',
    };
    return conditions[code] ?? 'Unknown';
  }

  static String weatherIcon(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (code <= 55) return '🌦️';
    if (code <= 65) return '🌧️';
    if (code <= 75) return '❄️';
    if (code <= 82) return '🌧️';
    if (code <= 86) return '🌨️';
    return '⛈️';
  }

  static String windDirectionLabel(int degrees) {
    const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    return dirs[(degrees / 22.5).round() % 16];
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final double precipitation;

  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.precipitation,
  });
}

class DailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;
  final double precipitationSum;
  final double windSpeedMax;

  const DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
    required this.precipitationSum,
    required this.windSpeedMax,
  });
}

class WeatherService {
  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const _cacheKey = 'weather_cache_';
  static const _cacheDuration = Duration(minutes: 30);

  Future<WeatherData?> getWeather(double latitude, double longitude,
      {String? farmId}) async {
    final cacheKey = '$_cacheKey${farmId ?? '${latitude}_$longitude'}';

    try {
      final url = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,pressure_msl'
        '&hourly=temperature_2m,weather_code,precipitation'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max'
        '&timezone=auto&forecast_days=7',
      );

      final response = await http.get(url).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weather = WeatherData.fromJson(data);
        await _cacheWeather(cacheKey, weather);
        return weather;
      }
      return await _getCachedWeather(cacheKey);
    } catch (_) {
      return await _getCachedWeather(cacheKey);
    }
  }

  Future<void> _cacheWeather(String key, WeatherData weather) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'temperature': weather.temperature,
        'feelsLike': weather.feelsLike,
        'weatherCode': weather.weatherCode,
        'condition': weather.condition,
        'humidity': weather.humidity,
        'windSpeed': weather.windSpeed,
        'windDirection': weather.windDirection,
        'windGusts': weather.windGusts,
        'pressure': weather.pressure,
        'precipitation': weather.precipitation,
        'timestamp': weather.timestamp.toIso8601String(),
      };
      await prefs.setString(key, json.encode(data));
      await prefs.setString('${key}_time', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<WeatherData?> _getCachedWeather(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString('${key}_time');
      if (timeStr == null) return null;
      final cachedTime = DateTime.tryParse(timeStr);
      if (cachedTime == null) return null;
      if (DateTime.now().difference(cachedTime) > _cacheDuration) return null;

      final dataStr = prefs.getString(key);
      if (dataStr == null) return null;
      final data = json.decode(dataStr);
      return WeatherData(
        temperature: (data['temperature'] as num?)?.toDouble() ?? 0,
        feelsLike: (data['feelsLike'] as num?)?.toDouble() ?? 0,
        weatherCode: data['weatherCode'] ?? 0,
        condition: data['condition'] ?? 'Unknown',
        humidity: data['humidity'] ?? 0,
        windSpeed: (data['windSpeed'] as num?)?.toDouble() ?? 0,
        windDirection: data['windDirection'] ?? 0,
        windGusts: (data['windGusts'] as num?)?.toDouble() ?? 0,
        pressure: (data['pressure'] as num?)?.toDouble() ?? 0,
        precipitation: (data['precipitation'] as num?)?.toDouble(),
        timestamp: cachedTime,
      );
    } catch (_) {
      return null;
    }
  }
}
