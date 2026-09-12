import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/features/farm/crop_stage.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/market_price_service.dart';
import 'package:vidhai/services/weather_service.dart';

/// Single, real source of "who is farming, where, with what".
///
/// Gathers everything the AI layer is allowed to use (farmer profile, selected
/// farm, active/historical crops, expenses, live-or-cached weather and cached
/// market context) into one typed [AiContextSnapshot]. Every lookup is guarded
/// so a missing/offline field degrades to an honest empty value — never to a
/// fabricated one.
///
/// The snapshot also produces a stable [AiContextSnapshot.contextHash] so
/// recommendation results can be cached and invalidated only when the actual
/// decision context changes.
class AIContextBuilder {
  AIContextBuilder({
    Future<UserProfile?> Function()? loadProfile,
    Future<List<FarmProfile>> Function()? loadFarms,
    Future<List<CropRecord>> Function(String farmId)? loadCrops,
    Future<List<ExpenseRecord>> Function(String farmId)? loadExpenses,
    Future<WeatherData?> Function(double latitude, double longitude,
            {String? farmId})?
        loadWeather,
    Future<List<Map<String, dynamic>>> Function(String state,
            {String? district})?
        loadMarket,
  })  : _loadProfile = loadProfile ?? _defaultLoadProfile,
        _loadFarms = loadFarms ?? _defaultLoadFarms,
        _loadCrops = loadCrops ?? _defaultLoadCrops,
        _loadExpenses = loadExpenses ?? _defaultLoadExpenses,
        _loadWeather = loadWeather ?? _defaultLoadWeather,
        _loadMarket = loadMarket ?? _defaultLoadMarket;

  final Future<UserProfile?> Function() _loadProfile;
  final Future<List<FarmProfile>> Function() _loadFarms;
  final Future<List<CropRecord>> Function(String farmId) _loadCrops;
  final Future<List<ExpenseRecord>> Function(String farmId) _loadExpenses;
  final Future<WeatherData?> Function(double latitude, double longitude,
      {String? farmId}) _loadWeather;
  final Future<List<Map<String, dynamic>>> Function(String state,
      {String? district}) _loadMarket;

  /// Builds a context snapshot for the current user. When [farm] is null the
  /// active farm (or the first available farm) is picked automatically; if no
  /// farm exists the snapshot still carries the farmer-level fields.
  Future<AiContextSnapshot> build({
    FarmProfile? farm,
    String? languageCode,
  }) async {
    final now = DateTime.now();
    final code = languageCode ?? 'en';

    final user = await _guarded(_loadProfile);
    final farms = await _guarded(_loadFarms) ?? const <FarmProfile>[];
    FarmProfile? selected;
    if (farm != null) {
      selected = farm;
    } else if (farms.isNotEmpty) {
      selected = farms.firstWhere((f) => f.isActive, orElse: () => farms.first);
    }

    List<CropRecord> crops = const [];
    List<ExpenseRecord> expenses = const [];
    var weather = <String, dynamic>{};
    var market = <Map<String, dynamic>>[];

    if (selected != null) {
      final farm = selected;
      crops = await _guarded(() => _loadCrops(farm.farmId)) ?? const [];
      expenses = await _guarded(() => _loadExpenses(farm.farmId)) ?? const [];

      final location = farm.farmLocation;
      if (location?.latitude != null && location?.longitude != null) {
        final w = await _guarded(
          () => _loadWeather(location!.latitude!, location.longitude!,
              farmId: farm.farmId),
        );
        if (w != null) weather = _weatherMap(w, now);
      }

      final state = extractStateValue(location) ?? '';
      if (state.isNotEmpty) {
        market = await _guarded(() => _loadMarket(
                  state,
                  district: extractDistrict(location),
                )) ??
            const [];
      }
    }

    final active = crops.where((c) => c.isActive).toList()
      ..sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
    final activeCrop = active.firstOrNull;
    final history = crops.where((c) => !c.isActive).toList()
      ..sort((a, b) =>
          (b.endDate ?? b.plantingDate).compareTo(a.endDate ?? a.plantingDate));

    return AiContextSnapshot(
      user: user,
      languageCode: code,
      farm: selected,
      crops: crops,
      activeCrop: activeCrop,
      cropHistory: history,
      expenses: expenses,
      weather: weather,
      marketContext: market,
      stageInfo: activeCrop != null ? _stageMap(activeCrop, now) : const {},
      season: _season(now.month),
      now: now,
    );
  }

  Map<String, dynamic> _stageMap(CropRecord crop, DateTime now) {
    final info = computeCropStage(crop);
    return {
      'cropName': crop.cropName,
      'variety': crop.variety,
      'stage': info.stage,
      'progress': ((info.progress ?? 0) * 100).round(),
      'daysSinceSowing': now.difference(crop.plantingDate).inDays,
      'expectedHarvestDate':
          crop.expectedHarvestDate?.toIso8601String().substring(0, 10),
    };
  }

  Map<String, dynamic> _weatherMap(WeatherData w, DateTime now) {
    final today = w.daily.firstOrNull;
    final next = w.daily.length > 1 ? w.daily[1] : null;
    final rainToday = today != null && _sameDay(today.date, now)
        ? today.precipitationSum
        : (w.precipitation ?? 0);
    final nextRain = today == null || _sameDay(today.date, now)
        ? (next?.precipitationSum ?? 0)
        : (today.precipitationSum);
    return {
      'temperature': w.temperature,
      'feelsLike': w.feelsLike,
      'condition': w.condition,
      'humidity': w.humidity,
      'windSpeed': w.windSpeed,
      'precipitation': w.precipitation,
      'todayRainMm': _round1(rainToday),
      'nextDayRainMm': _round1(nextRain),
      'heatAlert': w.temperature >= 38,
      'rainAlert': rainToday >= 5 || nextRain >= 10,
      'fetchedDate': now.toIso8601String().substring(0, 10),
    };
  }

  static Map<String, dynamic> _weatherCompact(Map<String, dynamic> w) {
    if (w.isEmpty) return const {};
    return {
      'temperatureBucket': ((w['temperature'] as num).round() / 5).round(),
      'todayRainBucket': ((w['todayRainMm'] as num) / 5).round(),
      'nextDayRainBucket': ((w['nextDayRainMm'] as num) / 10).round(),
      'condition': w['condition'],
      'date': w['fetchedDate'],
    };
  }

  Future<T?> _guarded<T>(Future<T> Function() fn, {T? fallback}) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[AIContextBuilder] field skipped: $e');
      return fallback;
    }
  }

  static Future<UserProfile?> _defaultLoadProfile() async {
    try {
      return await DataService().loadProfile();
    } catch (_) {
      return null;
    }
  }

  static Future<List<FarmProfile>> _defaultLoadFarms() async {
    try {
      return await DataService().loadFarms();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CropRecord>> _defaultLoadCrops(String farmId) async {
    try {
      return await DataService().loadCrops(farmId);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ExpenseRecord>> _defaultLoadExpenses(String farmId) async {
    try {
      return await DataService().loadExpenses(farmId);
    } catch (_) {
      return const [];
    }
  }

  static Future<WeatherData?> _defaultLoadWeather(
      double latitude, double longitude,
      {String? farmId}) async {
    return WeatherService().getWeather(latitude, longitude, farmId: farmId);
  }

  /// Cache-first market context; only when the cache is empty does it attempt
  /// a single short-lived live summary so first runs are still informed.
  static Future<List<Map<String, dynamic>>> _defaultLoadMarket(String state,
      {String? district}) async {
    final service = MarketPriceService.instance;
    try {
      final cached =
          await service.cachedMarketContext(state, district: district);
      if (cached.isNotEmpty) return cached;
      final payload = await service
          .fetchSummary(state: state)
          .timeout(const Duration(seconds: 6));
      return _marketContext(payload.prices);
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, dynamic>> _marketContext(
      List<MarketPriceRecord> records) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    // Prefer recently reported records that carry a reliable per-kg price so
    // the AI never reasons from invented figures.
    records.sort((a, b) => b.date.compareTo(a.date));
    for (final r in records) {
      final key = r.commodity.toLowerCase();
      if (seen.add(key)) {
        out.add({
          'commodity': r.commodity,
          if (r.variety != null && r.variety!.isNotEmpty) 'variety': r.variety,
          'market': r.market,
          'district': r.district,
          'state': r.state,
          if (r.normalizedPricePerKg != null)
            'pricePerKg': r.normalizedPricePerKg,
          if (r.hasReliablePerKg) 'reliablePerKg': true,
          if (r.modalPrice != null) 'modalPrice': r.modalPrice,
          if (r.unitLabel.isNotEmpty) 'unitLabel': r.unitLabel,
          if (r.date.isNotEmpty) 'date': r.date,
        });
      }
      if (out.length >= 12) break;
    }
    return out;
  }

  static String _season(int month) {
    if (month >= 6 && month <= 9) return 'Kharif';
    if (month >= 10 || month <= 3) return 'Rabi';
    return 'Zaid';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static double _round1(double v) => (v * 10).roundToDouble() / 10;
}

/// Typed context snapshot handed to the AI layer and local engines.
class AiContextSnapshot {
  final UserProfile? user;
  final String languageCode;
  final FarmProfile? farm;
  final List<CropRecord> crops;
  final CropRecord? activeCrop;
  final List<CropRecord> cropHistory;
  final List<ExpenseRecord> expenses;
  final Map<String, dynamic> weather;
  final List<Map<String, dynamic>> marketContext;
  final Map<String, dynamic> stageInfo;
  final String season;
  final DateTime now;

  AiContextSnapshot({
    required this.user,
    required this.languageCode,
    required this.farm,
    required this.crops,
    required this.activeCrop,
    required this.cropHistory,
    required this.expenses,
    required this.weather,
    required this.marketContext,
    required this.stageInfo,
    required this.season,
    required this.now,
  });

  /// Honest minimal snapshot used when the full build cannot complete: only
  /// ties together whatever a caller already holds (never fabricates fields).
  AiContextSnapshot.basic({
    this.user,
    this.languageCode = 'en',
    this.farm,
    this.crops = const [],
    this.expenses = const [],
    DateTime? now,
  })  : activeCrop = null,
        cropHistory = const [],
        weather = const {},
        marketContext = const [],
        stageInfo = const {},
        season = AIContextBuilder._season(now?.month ?? DateTime.now().month),
        now = now ?? DateTime.now();

  String get languageName => aiLanguageName(languageCode);

  /// English display name for a VidhAI language code (for prompt construction).
  static String aiLanguageName(String code) {
    const names = <String, String>{
      'en': 'English',
      'ta': 'Tamil',
      'te': 'Telugu',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'hi': 'Hindi',
      'bn': 'Bengali',
      'mr': 'Marathi',
      'gu': 'Gujarati',
      'pa': 'Punjabi',
      'or': 'Odia',
      'as': 'Assamese',
      'ur': 'Urdu',
    };
    return names[code] ?? 'English';
  }

  // ── Legibility flags (what is safe to rely on) ─────────────────────────────

  Map<String, bool> get completeness {
    final location = farm?.farmLocation;
    return {
      'hasProfile': user != null && user!.age > 0,
      'hasFarm': farm != null,
      'hasLocation': (extractStateValue(location) ?? '').isNotEmpty,
      'hasSoil': (farm?.soilType ?? '').isNotEmpty,
      'hasWater': (farm?.waterAvailability ?? '').isNotEmpty,
      'hasActiveCrop': activeCrop != null,
      'hasHistory': cropHistory.isNotEmpty,
      'hasWeather': weather.isNotEmpty,
      'hasMarket': marketContext.isNotEmpty,
    };
  }

  /// Legacy farm map shape used by the existing online `/crop/*` calls —
  /// superset of the old [CropRecommendationService.farmContext].
  Map<String, dynamic> get farmMap {
    final f = farm;
    if (f == null) return <String, dynamic>{};
    final location = f.farmLocation;
    final state = extractStateValue(location) ?? '';
    final district = extractDistrict(location);
    final place = extractPlace(location);
    double? acres = double.tryParse(f.farmSize);
    if (acres == null || acres <= 0) acres = null;
    return {
      'farmId': f.farmId,
      'farmName': f.farmName,
      'index': f.index,
      'state': state,
      if (district != null && district.isNotEmpty) 'district': district,
      if (place != null && place.isNotEmpty) 'place': place,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'soilType': f.soilType,
      if (f.soilAiResult != null && (f.soilAiResult?.soilType ?? '').isNotEmpty)
        'soilAiAnalysis': f.soilAiResult!.soilType,
      'irrigationType': f.irrigationType,
      'waterSource': f.waterSource,
      'waterAvailability': f.waterAvailability,
      'farmingMethod': f.farmingMethod,
      'farmSizeAcres': acres,
      if (f.farmSizeUnit.isNotEmpty) 'farmSizeUnit': f.farmSizeUnit,
      'month': now.month,
      'season': season,
      if (marketContext.isNotEmpty) 'market': _marketCompact,
    };
  }

  List<Map<String, dynamic>> get _marketCompact {
    return marketContext.map((m) {
      return {
        'commodity': m['commodity'],
        if (m['market'] != null) 'market': m['market'],
        if (m['district'] != null) 'district': m['district'],
        if (m['state'] != null) 'state': m['state'],
        if (m['pricePerKg'] != null) 'pricePerKg': m['pricePerKg'],
        if (m['date'] != null) 'date': m['date'],
      };
    }).toList();
  }

  Map<String, dynamic> get _historyCompact {
    final out = <Map<String, dynamic>>[];
    for (final c in cropHistory.take(8)) {
      out.add({
        'crop': c.cropName,
        'category': c.category,
        'status': c.status,
        if (c.endDate != null)
          'endDate': c.endDate!.toIso8601String().substring(0, 10),
      });
    }
    return {
      'count': cropHistory.length,
      'lastCrop': cropHistory.isNotEmpty ? cropHistory.first.cropName : null,
      'crops': out,
    };
  }

  Map<String, dynamic> get _expenseSummary {
    if (expenses.isEmpty) return const {};
    var total = 0.0;
    final byCategory = <String, double>{};
    for (final e in expenses) {
      total += e.amount;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    String top = '';
    var topAmount = 0.0;
    byCategory.forEach((k, v) {
      if (v > topAmount) {
        top = k;
        topAmount = v;
      }
    });
    return {
      'count': expenses.length,
      'totalInr': total,
      if (top.isNotEmpty) 'topCategory': top,
      if (topAmount > 0) 'topCategorySpend': topAmount,
    };
  }

  /// Full structured payload for the online AI brain (spec §2 context bundle).
  Map<String, dynamic> toBackendContext() {
    final f = farm;
    final location = f?.farmLocation;
    final farmer = <String, dynamic>{
      'gender': (user?.gender ?? ''),
      'age': user?.age ?? 0,
      'name': user?.displayName ?? '',
    };
    return {
      'farmer': farmer,
      'language': {'code': languageCode, 'name': languageName},
      'location': {
        'state': extractStateValue(location) ?? (f?.farmLocation?.state ?? ''),
        'district': extractDistrict(location) ?? '',
        'place': extractPlace(location) ?? '',
        'latitude': location?.latitude,
        'longitude': location?.longitude,
      },
      'farm': farmMap,
      'soil': {
        'type': f?.soilType ?? '',
        if (f?.soilAiResult != null &&
            (f?.soilAiResult?.soilType ?? '').isNotEmpty)
          'aiAnalysis': f!.soilAiResult!.soilType,
      },
      'water': {
        'availability': f?.waterAvailability ?? '',
        'source': f?.waterSource ?? '',
        'irrigation': f?.irrigationType ?? '',
      },
      'season': season,
      'currentCrops': [
        if (activeCrop != null) stageInfo,
      ],
      'cropHistory': _historyCompact,
      'expenses': _expenseSummary,
      'weather': AIContextBuilder._weatherCompact(weather),
      'marketPrices': _marketCompact,
      'date': now.toIso8601String().substring(0, 10),
    };
  }

  /// Compact, deterministic payload for the on-device knowledge-base engine.
  Map<String, dynamic> toLocalContext() {
    final state = farmMap['state'] ?? '';
    return {
      'state': state,
      'district': farmMap['district'] ?? '',
      'soilType': farm?.soilType ?? '',
      'waterAvailability': farm?.waterAvailability ?? '',
      'irrigationType': farm?.irrigationType ?? '',
      'farmingMethod': farm?.farmingMethod ?? '',
      'currentSeason': season,
      'month': now.month,
      'previousCrops': cropHistory.map((c) => c.cropName).toList(),
      'activeCrop': activeCrop?.cropName,
      'haveMarket': marketContext.isNotEmpty,
    };
  }

  /// Stable identifier of the decision context: two snapshots produce the
  /// same hash whenever the inputs that actually matter (farm, crop stage,
  /// weather buckets, market prices, season, farmer skeleton) are unchanged.
  /// Used to invalidate cached recommendation results.
  String get contextHash {
    final payload = <String, dynamic>{
      'farmer': {
        'gender': user?.gender ?? '',
        'age': user?.age ?? 0,
      },
      'language': languageCode,
      'season': season,
      'month': now.month,
      'farm': farmMap,
      'activeCrop': stageInfo,
      'history': _historyCompact,
      'expenses': _expenseSummary,
      'weather': AIContextBuilder._weatherCompact(weather),
      'market': marketContext.where((m) => m['pricePerKg'] != null).map((m) {
        final v = m['pricePerKg'].toString();
        return '${m['commodity']}:${double.parse(v).toStringAsFixed(0)}';
      }).toList(),
    };
    final canonical = _canonicalJson(payload);
    return _fnv1a(canonical);
  }

  static String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => '$k').toList()..sort();
      final out = StringBuffer('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        out.write(jsonEncode(keys[i]));
        out.write(':');
        out.write(_canonicalJson(value[keys[i]]));
      }
      out.write('}');
      return out.toString();
    }
    if (value is List) {
      final out = StringBuffer('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) out.write(',');
        out.write(_canonicalJson(value[i]));
      }
      out.write(']');
      return out.toString();
    }
    return jsonEncode(value);
  }

  static String _fnv1a(String input) {
    final bytes = utf8.encode(input);
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3).toUnsigned(64);
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
