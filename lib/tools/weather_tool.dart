import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../tools/ai_tool.dart';

/// Returns real current weather for the farmer's own farm via the existing
/// Open-Meteo-backed WeatherService.
class WeatherTool extends VidhAITool {
  WeatherTool();
  final DataService _data = DataService();

  @override
  String get name => 'GET_WEATHER';

  @override
  String get description =>
      'Get the current weather for the farmer\'s selected farm '
      '(temperature in Celsius, conditions, humidity, wind speed, rain chance). '
      'Uses the farm location the farmer already saved. Returns a clear message '
      'if the location cannot be resolved.';

  @override
  Map<String, dynamic> get parameters => withRequired(
        <String>[],
        {
          'farmId': stringParam(),
          'days': stringParam(),
        },
      );

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    final farms = await _data.loadFarms();
    if (farms.isEmpty) {
      return {
        'error':
            'No farm saved yet, so weather is not available. Add a farm first.',
      };
    }

    var farm = farms.first.toMap();
    final farmId = (arguments['farmId'] ?? '').toString();
    if (farmId.isNotEmpty) {
      for (final f in farms) {
        final m = f.toMap();
        if ((m['farmId'] ?? m['id'] ?? '') == farmId) {
          farm = m;
          break;
        }
      }
    }

    final address = (farm['farmLocation'] ?? farm['location'] ?? '').toString();
    final farmName = (farm['farmName'] ?? 'your farm').toString();
    if (address.trim().isEmpty) {
      return {
        'error':
            'This farm has no saved location, so its weather cannot be fetched.',
      };
    }

    double? lat;
    double? lng;
    final loc = await LocationService().getCoordinatesFromAddress(address);
    if (loc.isNotEmpty) {
      lat = loc.first.latitude;
      lng = loc.first.longitude;
    }
    if (lat == null || lng == null) {
      return {
        'error':
            'Could not resolve the location of $farmName from its saved address.',
      };
    }

    final weather = await WeatherService().getWeather(lat, lng);
    if (weather == null) {
      return {'error': 'Weather is unavailable right now. Please try again.'};
    }

    return {
      'farm': farmName,
      'temperatureC': weather.temperature,
      'feelsLikeC': weather.feelsLike,
      'condition': weather.condition,
      'humidityPercent': weather.humidity,
      'windSpeedKmh': weather.windSpeed,
      'precipitationMm': weather.precipitation,
      'forecastToday': weather.daily.isNotEmpty
          ? {
              'maxTempC': weather.daily.first.maxTemp,
              'minTempC': weather.daily.first.minTemp,
              'condition': _codeToCondition(weather.daily.first.weatherCode),
              'precipitationSumMm': weather.daily.first.precipitationSum,
            }
          : null,
      'summary': '${weather.condition}, ${weather.temperature}°C, humidity '
          '${weather.humidity}%, wind ${weather.windSpeed} km/h',
    };
  }

  String _codeToCondition(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 48) return 'Fog';
    if (code <= 65) return 'Rain';
    if (code <= 75) return 'Snow';
    if (code <= 82) return 'Rain showers';
    if (code <= 86) return 'Snow showers';
    return 'Thunderstorm';
  }
}
