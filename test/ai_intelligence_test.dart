import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/ai/ai_context_builder.dart';
import 'package:vidhai/services/farm_ai_summary_service.dart';
import 'package:vidhai/services/farm_recommendation_service.dart';
import 'package:vidhai/services/task_service.dart';
import 'package:vidhai/services/weather_service.dart';

// ── Shared fixtures ──────────────────────────────────────────────────────

final _farmer = UserProfile(
  uid: 'u1',
  email: 'a@b.com',
  displayName: 'Ramesh',
  gender: 'M',
  age: 35,
);

final _farm = FarmProfile(
  farmId: 'f1',
  index: 0,
  farmName: 'Main Farm',
  farmSize: '5',
  farmLocation: const AddressData(
    fullAddress: 'Village, Pune, Maharashtra',
    latitude: 18.52,
    longitude: 73.86,
    district: 'Pune',
    state: 'Maharashtra',
  ),
  soilType: 'Loam',
  waterAvailability: 'Medium',
  farmingMethod: 'Organic',
  irrigationType: 'Drip',
);

final _activeCrop = CropRecord(
  id: 'c1',
  farmId: 'f1',
  cropName: 'Tomato',
  variety: 'Roma',
  category: 'Vegetable',
  duration: '90 days',
  plantingDate: DateTime.now().subtract(const Duration(days: 50)),
  expectedHarvestDate: DateTime.now().add(const Duration(days: 40)),
  status: 'active',
);

final _historyCrop = CropRecord(
  id: 'c2',
  farmId: 'f1',
  cropName: 'Onion',
  variety: 'Red',
  category: 'Vegetable',
  duration: '60 days',
  plantingDate: DateTime.now().subtract(const Duration(days: 80)),
  expectedHarvestDate: DateTime.now().subtract(const Duration(days: 20)),
  status: 'harvested',
  endDate: DateTime.now().subtract(const Duration(days: 20)),
);

final _expenses = [
  ExpenseRecord(
    id: 'e1',
    farmId: 'f1',
    category: 'Seeds',
    amount: 5000,
    date: DateTime.now(),
    description: 'seeds',
  ),
  ExpenseRecord(
    id: 'e2',
    farmId: 'f1',
    category: 'Fertilizer',
    amount: 3000,
    date: DateTime.now(),
    description: 'fert',
  ),
];

AIContextBuilder _fakeBuilder({
  Future<UserProfile?> Function()? loadProfile,
  Future<List<CropRecord>> Function(String)? loadCrops,
  Future<WeatherData?> Function(double, double, {String? farmId})? loadWeather,
  Future<List<Map<String, dynamic>>> Function(String, {String? district})?
      loadMarket,
}) =>
    AIContextBuilder(
      loadProfile: loadProfile ?? () async => _farmer,
      loadFarms: () async => [_farm],
      loadCrops: loadCrops ?? (_) async => [_activeCrop, _historyCrop],
      loadExpenses: (_) async => _expenses,
      loadWeather: loadWeather ?? (_, __, {farmId}) async => null,
      loadMarket: loadMarket ?? (_, {district}) async => [],
    );

// ── Tests ────────────────────────────────────────────────────────────────

void main() {
  group('AIContextBuilder', () {
    test('picks active crop, computes stageInfo and expense history', () async {
      final snap = await _fakeBuilder().build(farm: _farm);

      expect(snap.activeCrop?.cropName, 'Tomato');
      expect(snap.stageInfo['stage'], isNotNull);
      expect(snap.stageInfo['progress'], isA<int>());
      expect(snap.cropHistory, hasLength(1));
      expect(snap.cropHistory.first.cropName, 'Onion');
      expect(snap.expenses, hasLength(2));
      expect(snap.weather, isEmpty);
      expect(snap.season, isNotEmpty);
    });

    test('contextHash changes when farm soil type changes', () async {
      final hash1 = await _fakeBuilder().build(farm: _farm);
      final changedFarm = FarmProfile(
        farmId: _farm.farmId,
        index: _farm.index,
        farmName: _farm.farmName,
        farmSize: _farm.farmSize,
        farmLocation: _farm.farmLocation,
        soilType: 'Clay',
        waterAvailability: _farm.waterAvailability,
        farmingMethod: _farm.farmingMethod,
        irrigationType: _farm.irrigationType,
      );
      final hash2 = await _fakeBuilder().build(farm: changedFarm);

      expect(hash1.contextHash, isNotEmpty);
      expect(hash2.contextHash, isNotEmpty);
      expect(hash1.contextHash, isNot(hash2.contextHash));
    });

    test('basic fallback snapshot has no active crop', () {
      final snap = AiContextSnapshot.basic(farm: _farm);
      expect(snap.activeCrop, isNull);
      expect(snap.weather, isEmpty);
      expect(snap.marketContext, isEmpty);
      expect(snap.stageInfo, isEmpty);
    });
  });

  group('FarmRecommendationService', () {
    test('same inputs produce identical scores and order', () {
      final svc = FarmRecommendationService();
      final q = CropSetupQuestionnaire(
        cropDurationPreference: '',
        cropCategoryPreference: '',
        lastCrop: '',
      );
      final a = svc.getRecommendations(
        farm: _farm,
        questionnaire: q,
        currentSeason: 'Rabi',
      );
      final b = svc.getRecommendations(
        farm: _farm,
        questionnaire: q,
        currentSeason: 'Rabi',
      );
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].cropId, b[i].cropId, reason: 'crop mismatch at $i');
        expect(a[i].score, b[i].score, reason: 'score mismatch at $i');
      }
    });

    test('marketContext bonus boosts matching crop', () {
      final svc = FarmRecommendationService();
      final market = <Map<String, dynamic>>[
        {'commodity': 'Rice', 'pricePerKg': 28},
      ];
      final withMarket = svc.getRecommendations(
        farm: _farm,
        currentSeason: 'Kharif',
        currentMonth: '7',
        marketContext: market,
      );
      final without = svc.getRecommendations(
        farm: _farm,
        currentSeason: 'Kharif',
        currentMonth: '7',
      );

      final riceWith = withMarket.firstWhere(
        (r) => r.cropName.toLowerCase() == 'rice',
        orElse: () => withMarket.last,
      );
      final riceWithout = without.firstWhere(
        (r) => r.cropName.toLowerCase() == 'rice',
        orElse: () => without.last,
      );
      expect(riceWith.score, greaterThanOrEqualTo(riceWithout.score));
    });
  });

  group('WeatherData.alertContext', () {
    test('heatAlert true when temp >= 38', () {
      final w = WeatherData(
        temperature: 40.0,
        feelsLike: 44,
        weatherCode: 0,
        condition: 'Hot',
        humidity: 45,
        windSpeed: 10,
        windDirection: 180,
        windGusts: 12,
        pressure: 1010,
        precipitation: 0,
        timestamp: DateTime(2025),
      );
      final ctx = WeatherData.alertContext(w);
      expect(ctx['heatAlert'], isTrue);
      expect(ctx['rainAlert'], isFalse);
    });

    test('rainAlert true when next-day precipitation >= 10', () {
      final daily = [
        DailyForecast(
          date: DateTime(2025, 7, 2),
          maxTemp: 30,
          minTemp: 22,
          weatherCode: 61,
          precipitationSum: 2,
          windSpeedMax: 10,
        ),
        DailyForecast(
          date: DateTime(2025, 7, 3),
          maxTemp: 28,
          minTemp: 20,
          weatherCode: 65,
          precipitationSum: 12,
          windSpeedMax: 14,
        ),
      ];
      final w = WeatherData(
        temperature: 29.5,
        feelsLike: 31,
        weatherCode: 61,
        condition: 'Rain',
        humidity: 88,
        windSpeed: 8,
        windDirection: 90,
        windGusts: 10,
        pressure: 1008,
        precipitation: 1.5,
        timestamp: DateTime(2025, 7, 2),
        daily: daily,
      );
      final ctx = WeatherData.alertContext(w, DateTime(2025, 7, 2));
      expect(ctx['rainAlert'], isTrue);
      expect(ctx['heatAlert'], isFalse);
    });
  });

  group('TaskService context-aware generation', () {
    test('base tasks always generated without weather', () {
      final farms = [_farm.toMap()];
      final tasks = TaskService.generateTasksFromFarms(farms);
      final categories = tasks.map((t) => t.category).toSet();
      expect(categories, containsAll(['irrigation', 'monitoring', 'pest']));
      expect(categories, isNot(contains('weather')));
    });

    test('rainAlert adds a weather-category task mentioning spraying', () {
      final tasks = TaskService.generateTasksFromFarms(
        [_farm.toMap()],
        weatherByFarmIndex: {
          0: {'rainAlert': true, 'heatAlert': false, 'humidity': 70},
        },
      );
      final wx = tasks.where((t) => t.category == 'weather').toList();
      expect(wx, isNotEmpty);
      expect(wx.first.title.toLowerCase(), contains('rain'));
      expect(wx.first.title.toLowerCase(), contains('spraying'));
    });

    test('heatAlert adds a weather task mentioning irrigation', () {
      final tasks = TaskService.generateTasksFromFarms(
        [_farm.toMap()],
        weatherByFarmIndex: {
          0: {'rainAlert': false, 'heatAlert': true, 'humidity': 50},
        },
      );
      final wx = tasks.where((t) => t.category == 'weather').toList();
      expect(wx, isNotEmpty);
      expect(wx.first.title.toLowerCase(), contains('heat'));
      expect(wx.first.title.toLowerCase(), contains('irrigate'));
    });

    test('crop stage Flowering adds a specific monitoring task', () {
      final tasks = TaskService.generateTasksFromFarms(
        [_farm.toMap()],
        cropNameByFarmIndex: {0: 'Rice'},
        stageByFarmIndex: {0: 'Flowering'},
      );
      final stageTasks = tasks
          .where((t) => t.title.toLowerCase().contains('flowering'))
          .toList();
      expect(stageTasks, isNotEmpty);
      expect(stageTasks.first.title, contains('Rice'));
    });

    test('high humidity adds a pest-category fungal warning', () {
      final tasks = TaskService.generateTasksFromFarms(
        [_farm.toMap()],
        weatherByFarmIndex: {
          0: {'rainAlert': false, 'heatAlert': false, 'humidity': 90},
        },
      );
      final fungal =
          tasks.where((t) => t.title.toLowerCase().contains('fungal')).toList();
      expect(fungal, isNotEmpty);
      expect(fungal.first.category, 'pest');
    });
  });

  group('FarmAiSummaryService', () {
    test('returns honest data-derived points', () async {
      final svc = FarmAiSummaryService(
        contextBuilder: _fakeBuilder(),
        narrativeProvider: (_, __) async => null,
      );
      final summary = await svc.summarize(_farm, languageCode: 'en');

      expect(summary.season, isNotEmpty);
      expect(summary.hasActiveCrop, isTrue);
      expect(summary.activeCrop, 'Tomato');
      expect(summary.cropStage, isNotNull);
      expect(summary.historyNames, ['Onion']);
      expect(summary.expenseCount, 2);
      expect(summary.expenseTotal, 8000);
      expect(summary.online, isFalse);
      expect(summary.aiNarrative, isNull);
    });

    test('injectable narrative provider attaches AI response', () async {
      final svc = FarmAiSummaryService(
        contextBuilder: _fakeBuilder(),
        narrativeProvider: (_, __) async => 'Tomato is healthy.',
      );
      final summary = await svc.summarize(_farm, languageCode: 'en');

      expect(summary.online, isTrue);
      expect(summary.aiNarrative, 'Tomato is healthy.');
    });
  });
}
