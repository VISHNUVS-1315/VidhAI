import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/crop_recommendation_service.dart';

FarmProfile _farm({String state = 'Tamil Nadu'}) => FarmProfile(
      farmId: 'farm1',
      index: 0,
      farmName: 'Test Farm',
      farmSize: '2',
      farmSizeUnit: 'Acres',
      farmLocation: AddressData(
        fullAddress: 'Erode, Tamil Nadu',
        state: state,
        district: 'Erode',
      ),
      irrigationType: 'Drip',
      waterSource: 'Borewell',
      soilType: 'Loamy',
      waterAvailability: 'Medium',
      farmingMethod: 'Organic',
      isActive: true,
    );

CropSetupQuestionnaire _questionnaire({String? category}) =>
    CropSetupQuestionnaire(
      currentSeason: 'Kharif',
      soilType: 'Loamy',
      waterAvailability: 'Medium',
      cropDurationPreference: 'No preference',
      cropCategoryPreference: category ?? '',
    );

CropRecommendationResult _cacheRec() => CropRecommendationResult(
      rank: 1,
      cropId: 'CR_CACHE',
      cropName: 'CachedCrop',
      varieties: const ['V1'],
      category: 'Pulses',
      season: 'Kharif',
      durationMin: 60,
      durationMax: 80,
      score: 85,
      confidence: 'High',
      budget: const CropBudgetEstimate(
        classification: 'Not Specified',
        cultivationCostMin: 0,
        cultivationCostMax: 0,
        seedCostMin: 0,
        seedCostMax: 0,
      ),
      money: const CropMoneyEstimate(
        yieldMin: 0,
        yieldMax: 0,
        yieldUnit: '',
        revenueMin: 0,
        revenueMax: 0,
        profitMin: 0,
        profitMax: 0,
      ),
      factors: const [],
      strengths: const ['Cached strength'],
      concerns: const [],
      waterNotes: '',
      plantingWindow: 'Jun-Jul',
      harvestHint: '',
      risks: const [],
      pests: const [],
      diseases: const [],
      marketDemand: 'High',
      riskLevel: 'Low',
      description: 'Cached description',
      estimatedLabel: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns a valid offline top-10 list when online is unavailable', () async {
    SharedPreferences.setMockInitialValues({});

    final results = await CropRecommendationService.instance.getRecommendations(
        farm: _farm(), questionnaire: _questionnaire());

    expect(results, isNotEmpty);
    expect(results.length, lessThanOrEqualTo(10));
    for (final r in results) {
      expect(r.cropName, isNotEmpty, reason: 'every card must name a crop');
      expect(r.score, inInclusiveRange(0, 100));
      expect(r.strengths, isNotEmpty, reason: 'every card must explain why');
      expect(r.plantingWindow, isNotEmpty);
    }
    // ranks must be a sequential 1..n
    for (var i = 0; i < results.length; i++) {
      expect(results[i].rank, i + 1);
    }
  });

  test('honours the crop category preference in the fallback list', () async {
    SharedPreferences.setMockInitialValues({});

    final results = await CropRecommendationService.instance.getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Pulses'));

    expect(results, isNotEmpty);
    for (final r in results) {
      expect(r.category, 'Pulses',
          reason: 'category filter must be applied to fallback results');
    }
  });

  test('returns cached online results when present and offline', () async {
    SharedPreferences.setMockInitialValues({
      'crop_top10_farm1': json.encode({
        'payload': {'top10': [_cacheRec().toMap()]},
        'fetchedAt': DateTime.now().toIso8601String(),
      }),
    });

    final results = await CropRecommendationService.instance.getRecommendations(
        farm: _farm(), questionnaire: _questionnaire());

    expect(results, isNotEmpty);
    expect(results.single.cropName, 'CachedCrop',
        reason: 'a non-empty cached top-10 must be served before the local fallback');
    expect(results.single.score, 85);
  });

  test('does not short-circuit on an empty cache envelope', () async {
    SharedPreferences.setMockInitialValues({
      'crop_top10_farm1': json.encode({
        'payload': {
          'top10': <Map<String, dynamic>>[],
        },
        'fetchedAt': DateTime.now().toIso8601String(),
      }),
    });

    final results = await CropRecommendationService.instance.getRecommendations(
        farm: _farm(), questionnaire: _questionnaire());

    expect(results, isNotEmpty,
        reason: 'an empty cached result must fall through to the local engine');
  });
}