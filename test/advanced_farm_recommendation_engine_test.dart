import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/crop_agronomy_data.dart';
import 'package:vidhai/services/crop_analytics.dart';
import 'package:vidhai/services/crop_knowledge_base.dart';
import 'package:vidhai/services/farm_recommendation_service.dart';

FarmProfile _farm({
  String state = 'Tamil Nadu',
  String district = 'Erode',
  String? soilType = 'Loamy',
  String water = 'Medium',
  String? size = '2',
  String unit = 'Acres',
}) =>
    FarmProfile(
      farmId: 'farm1',
      index: 0,
      farmName: 'Test Farm',
      farmSize: size ?? '',
      farmSizeUnit: unit,
      farmLocation: AddressData(
        fullAddress: '',
        state: state,
        district: district,
      ),
      irrigationType: 'Drip',
      waterSource: 'Borewell',
      soilType: soilType ?? '',
      waterAvailability: water,
      farmingMethod: 'Organic',
      isActive: true,
    );

CropSetupQuestionnaire _questionnaire({
  String category = '',
  String duration = 'No preference',
  String lastCrop = '',
  int? budget,
}) =>
    CropSetupQuestionnaire(
      currentSeason: 'Kharif',
      soilType: 'Loamy',
      waterAvailability: 'Medium',
      cropDurationPreference: duration,
      cropCategoryPreference: category,
      lastCrop: lastCrop,
      budgetInrPerAcre: budget,
    );

Map<String, dynamic> _weather({num? cacheAgeHours}) => {
      'temperature': 30,
      'todayRainMm': 0,
      'nextDayRainMm': 0,
      'condition': 'Sunny',
      'fetchedDate': '2026-09-01',
      if (cacheAgeHours != null) 'cacheAgeHours': cacheAgeHours,
    };

void main() {
  group('Hard filters', () {
    test('category preference is a hard filter that is never widened', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Pulses'),
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.category, 'Pulses');
      }
    });

    test('survey category alias Leafy -> Leafy Vegetables', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Leafy'),
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.category, 'Leafy Vegetables');
      }
    });

    test('divergent category Fibre returns an honest empty list', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Fibre'),
      );
      expect(results, isEmpty,
          reason: 'no verified Fibre crops exist, so the engine must not pad');
    });

    test('No preference and Other behave as "no category chosen"', () {
      for (final category in ['No preference', 'Other', '']) {
        final results = FarmRecommendationService().getRecommendations(
          farm: _farm(),
          questionnaire: _questionnaire(category: category),
        );
        expect(results, isNotEmpty,
            reason: 'category $category must not filter anything');
      }
    });

    test('short duration preference keeps only short crops', () {
      final kb = CropKnowledgeBase();
      final shortIds =
          kb.allCrops.where((c) => c.durationCategory == 'short').map((c) => c.id).toSet();
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(duration: 'Short'),
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(shortIds.contains(r.cropId), isTrue,
            reason: '${r.cropName} is not a short-duration crop');
      }
    });

    test('combined category + duration still yields only qualifying crops', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(
            category: 'Vegetables', duration: 'Medium'),
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.category, 'Vegetables');
      }
      expect(results.length, lessThanOrEqualTo(10));
    });

    test('empty and blank state/district never crash or reject', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(state: '', district: ''),
        questionnaire: _questionnaire(),
      );
      expect(results, isNotEmpty);
      expect(results.length, lessThanOrEqualTo(10));
    });
  });

  group('Determinism', () {
    test('same inputs twice produce identical order with identical scores', () {
      List<String> run() => FarmRecommendationService()
          .getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Pulses'),
        currentMonth: '6',
        weather: _weather(),
      )
          .map((r) => '${r.cropId}:${r.score.toStringAsFixed(6)}')
          .toList();
      expect(run(), run());
    });
  });

  group('Transparent scoring', () {
    test('every result scores 1..100 with all 12 components exposed', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(),
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.score, inInclusiveRange(1, 100));
        expect(r.scoreComponents.length, 12);
        final total = r.scoreComponents.values.fold(0.0, (a, b) => a + b);
        expect(total, lessThanOrEqualTo(100.01));
      }
    });

    test('full data normalizes to 100 and score matches components', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Pulses', budget: 40000),
        currentMonth: '6',
        marketContext: [
          {'commodity': 'Green Gram (Moong)', 'pricePerKg': 60, 'source': 'CMTI', 'date': '2026-09-01'},
        ],
        weather: _weather(),
        farmAreaAcres: 2,
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.confidencePct, 90,
            reason:
                'rotation weight is excluded (no history, score >= 0.5), so 100 - 10');
        final total = r.scoreComponents.values.fold(0.0, (a, b) => a + b);
        final scaled = total * 100 / 90;
        final lower = scaled > 100 ? 100 : scaled;
        final upper = (scaled + 0.5).clamp(0, 100).toDouble();
        expect(r.score, inInclusiveRange(lower, upper),
            reason: 'score is the normalized component total plus tie-break');
      }
    });

    test('minimal farm data shrinks confidence without crashing', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(state: '', district: '', soilType: null, size: '', water: ''),
        questionnaire: _questionnaire(),
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.confidencePct, 44,
            reason: 'location (10) + duration (10) + calendar (10) + '
                'investment (7) + profit (5) + risk (2)');
        expect(r.dataSources, contains('General database'));
        expect(r.score, inInclusiveRange(1, 100));
      }
    });
  });

  group('Crop calendar', () {
    test('June-sown crops are ideal_now in June and not_now in January', () {
      final june = FarmRecommendationService().getRecommendations(
        farm: _farm(state: '', district: ''),
        questionnaire: _questionnaire(),
        currentMonth: '6',
      );
      final juneJ = june.where((r) => r.sowingWindow == 'June-July').toList();
      expect(juneJ, isNotEmpty);
      for (final r in juneJ) {
        expect(r.calendarStatus, 'ideal_now');
      }

      final jan = FarmRecommendationService().getRecommendations(
        farm: _farm(state: '', district: ''),
        questionnaire: _questionnaire(),
        currentMonth: '1',
      );
      final janJ = jan.where((r) => r.sowingWindow == 'June-July').toList();
      expect(janJ, isNotEmpty);
      for (final r in janJ) {
        expect(r.calendarStatus, 'not_now');
      }
    });

    test('engine calendar status matches analytics re-derivation', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(state: '', district: ''),
        questionnaire: _questionnaire(),
        currentMonth: '6',
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        final expected = CropAnalytics.calendarStatus(
                CropAnalytics.parseMonthWindows(r.sowingWindow), 6)
            .status;
        expect(r.calendarStatus, expected,
            reason: 'UI status must be exactly what the analytics derive');
      }
      expect(results.any((r) => r.calendarStatus == 'ideal_now'), isTrue,
          reason: 'at least one June-sown crop must be ideal to plant now');
    });

    test('calendar status is always a known enum value', () {
      const allowed = {'unknown', 'ideal_now', 'sow_soon', 'next_window', 'not_now'};
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(state: '', district: ''),
        questionnaire: _questionnaire(),
        currentMonth: '6',
      );
      for (final r in results) {
        expect(allowed.contains(r.calendarStatus), isTrue);
        expect(r.sowingWindow, isNotEmpty);
        expect(r.harvestWindowLocal, isNotEmpty);
      }
    });
  });

  group('Rotation & farm history', () {
    test('no history yields a no_history explanation', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(),
      );
      for (final r in results) {
        expect(r.rotationAnalysis, contains('No previous crop history'));
      }
    });

    test('a qualifying crop away from history reads good rotation', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Pulses'),
        previousCrops: const ['Paddy'],
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.rotationAnalysis, contains('Rotates well away'));
        expect(r.previousCrop, 'Paddy');
      }
    });

    test('repeating the same crop is flagged as a risk', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Pulses'),
      );
      expect(results, isNotEmpty);
      final name = results.first.cropName;
      final repeat = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Pulses'),
        previousCrops: [name],
      );
      final same = repeat.where((r) => r.cropName == name).toList();
      expect(same, isNotEmpty);
      expect(same.first.rotationAnalysis, contains('same crop was grown recently'));
    });
  });

  group('Economics', () {
    test('totals scale per-acre figures by the farm area', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(size: '1', unit: 'Hectare'),
        questionnaire: _questionnaire(),
        farmAreaAcres: 2,
      );
      expect(results, isNotEmpty);
      for (final r in results) {
        expect(r.farmAreaAcres, 2);
        if (r.costPerAcre != null) {
          expect(r.totalCost, closeTo(r.costPerAcre! * 2, 0.001));
          expect(r.totalProfit, closeTo(r.profitPerAcre! * 2, 0.001));
          expect(r.totalRevenue, closeTo(r.revenuePerAcre! * 2, 0.001));
        }
      }
    });

    test('cost split lines sum to 100% and label every share', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(),
      );
      expect(results, isNotEmpty);
      final r = results.first;
      expect(r.costBreakdown, isNotNull);
      expect(r.costBreakdown!.length, greaterThanOrEqualTo(3));
      final shareSum =
          r.costBreakdown!.fold(0.0, (a, b) => a + b.sharePct);
      expect(shareSum, closeTo(100, 0.001));
      for (final line in r.costBreakdown!) {
        expect(line.label, isNotEmpty);
      }
    });

    test('profit margin is derived from per-acre revenue and profit', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(),
      );
      expect(results, isNotEmpty);
      final r = results.first;
      if (r.profitPerAcre != null && r.revenuePerAcre != null) {
        final expected = CropAnalytics.profitMargin(
            r.profitPerAcre!, r.revenuePerAcre!);
        expect(r.profitMarginPct, closeTo(expected, 0.001));
        expect(r.profitMarginPct, inInclusiveRange(0, 200));
      }
    });
  });

  group('Weather', () {
    test('live, cached and absent weather map to distinct labels', () {
      Map<String, String> statusFor(Map<String, dynamic>? w) {
        final res = FarmRecommendationService().getRecommendations(
          farm: _farm(),
          questionnaire: _questionnaire(),
          weather: w,
        );
        return {for (final r in res) r.weatherAvailability!: r.weatherAvailability!};
      }

      final live = statusFor(_weather(cacheAgeHours: 2));
      expect(live.keys.single, 'available');

      final cached = statusFor(_weather(cacheAgeHours: 20));
      expect(cached.keys.single, 'cached');

      final absent = statusFor(null);
      expect(absent.keys.single, 'absent');
    });

    test('weather bundle adds a Weather data source and boosts nothing phantom', () {
      final res = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(),
        weather: _weather(),
      );
      expect(res, isNotEmpty);
      for (final r in res) {
        expect(r.dataSources, contains('Weather'));
        expect(r.score, inInclusiveRange(1, 100));
      }
    });
  });

  group('Market price', () {
    test('market context attaches price data to the matching crop', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(category: 'Pulses'),
        marketContext: [
          {'commodity': 'Green Gram (Moong)', 'pricePerKg': 64, 'source': 'CMTI', 'date': '2026-09-01'},
        ],
      );
      final moong = results.where((r) => r.cropName == 'Green Gram (Moong)').toList();
      expect(moong, isNotEmpty);
      expect(moong.first.marketPricePerKg, 64);
      expect(moong.first.marketPriceSource, 'CMTI');
      expect(moong.first.marketPriceDate, '2026-09-01');
      expect(moong.first.dataSources, contains('Market price'));
    });

    test('absent market context still scores honestly', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(),
      );
      for (final r in results) {
        expect(r.score, inInclusiveRange(1, 100));
        expect(r.marketPricePerKg, isNull);
      }
    });
  });

  group('Risk', () {
    test('every result carries a risk explanation and a 1..10 score', () {
      final results = FarmRecommendationService().getRecommendations(
        farm: _farm(),
        questionnaire: _questionnaire(),
      );
      for (final r in results) {
        expect(r.riskExplanation, isNotNull);
        expect(r.riskExplanation, isNotEmpty);
        expect(r.riskScore, inInclusiveRange(1, 10));
      }
    });
  });

  group('CropAnalytics pure helpers', () {
    test('parseRange extracts the first numeric range midpoint', () {
      final r = CropAnalytics.parseRange('₹25,000–35,000');
      expect(r.min, 25000);
      expect(r.avg, 30000);
      expect(r.max, 35000);
      expect(CropAnalytics.parseRange(null).isKnown, isFalse);
      expect(CropAnalytics.parseRange('not available').isKnown, isFalse);
    });

    test('parseDurationRange handles days and garbage', () {
      expect(CropAnalytics.parseDurationRange('90-120 days'), (90, 120));
      expect(CropAnalytics.parseDurationRange('soon'), (0, 0));
    });

    test('parseMonthWindows handles dashes, lists and year-round', () {
      final a = CropAnalytics.parseMonthWindows('February-March');
      expect(a.length, 1);
      expect(a.single.startMonth, 2);
      expect(a.single.endMonth, 3);
      final b = CropAnalytics.parseMonthWindows('June-July, January-February');
      expect(b.length, 2);
      expect(b[0].startMonth, 6);
      expect(b[0].endMonth, 7);
      expect(b[1].startMonth, 1);
      expect(b[1].endMonth, 2);
      final y = CropAnalytics.parseMonthWindows('Throughout year');
      expect(y.single.startMonth, 1);
      expect(y.single.endMonth, 12);
      expect(CropAnalytics.parseMonthWindows('gibberish'), isEmpty);
    });

    test('calendarStatus respects year-boundary windows and unknown input', () {
      const decFeb = [MonthWindow(12, 2)];
      expect(CropAnalytics.calendarStatus(decFeb, 12).status, 'ideal_now');
      expect(CropAnalytics.calendarStatus(decFeb, 2).status, 'ideal_now');
      expect(CropAnalytics.calendarStatus(decFeb, 6).status, isNot('ideal_now'));
      expect(CropAnalytics.calendarStatus(const [], 6).status, 'unknown');
      expect(CropAnalytics.calendarStatus(const [], 6).isKnown, isFalse);
    });

    test('acresFromFarmSize converts acre, hectare and rejects garbage', () {
      expect(CropAnalytics.acresFromFarmSize('2', 'Acres'), 2.0);
      expect(CropAnalytics.acresFromFarmSize('1', 'Hectare'),
          closeTo(2.47105, 0.00001));
      expect(CropAnalytics.acresFromFarmSize('x', 'Acres'), isNull);
      expect(CropAnalytics.acresFromFarmSize('0', 'Acres'), isNull);
    });

    test('profitMargin guards zero revenue and clamps high ratios', () {
      expect(CropAnalytics.profitMargin(0, 0), 0);
      expect(CropAnalytics.profitMargin(50, 100), 50);
      expect(CropAnalytics.profitMargin(1000, 100), 200);
    });

    test('rotationAnalysis resolves every status deterministically', () {
      final f = CropAgronomyData.familyOf;
      expect(
          CropAnalytics.rotationAnalysis(
              candidateName: 'Rice',
              candidateFamily: 'Poaceae',
              candidateLegume: false,
              previousCrops: const [],
              familyOf: f)
              .status,
          'no_history');
      expect(
          CropAnalytics.rotationAnalysis(
              candidateName: 'Wheat',
              candidateFamily: 'Poaceae',
              candidateLegume: false,
              previousCrops: const ['Rice'],
              familyOf: f)
              .status,
          'same_family');
      expect(
          CropAnalytics.rotationAnalysis(
              candidateName: 'Wheat',
              candidateFamily: 'Poaceae',
              candidateLegume: false,
              previousCrops: ['Wheat'],
              familyOf: f)
              .status,
          'same_crop');
      expect(
          CropAnalytics.rotationAnalysis(
              candidateName: 'Paddy',
              candidateFamily: 'Poaceae',
              candidateLegume: false,
              previousCrops: const ['Green Gram (Moong)'],
              familyOf: f)
              .status,
          'legume_benefit');
      expect(
          CropAnalytics.rotationAnalysis(
              candidateName: 'Rice',
              candidateFamily: 'Poaceae',
              candidateLegume: false,
              previousCrops: const ['Green Gram (Moong)'],
              familyOf: f)
              .status,
          'legume_benefit');
      expect(
          CropAnalytics.rotationAnalysis(
              candidateName: 'Green Gram (Moong)',
              candidateFamily: 'Fabaceae',
              candidateLegume: true,
              previousCrops: const ['Black Gram (Urad)'],
              familyOf: f)
              .status,
          'same_family',
          reason: 'a legume after a legume is same-family, not a benefit');
      expect(
          CropAnalytics.rotationAnalysis(
              candidateName: 'Tomato',
              candidateFamily: 'Solanaceae',
              candidateLegume: false,
              previousCrops: const ['Rice'],
              familyOf: f)
              .status,
          'good_rotation');
    });
  });
}