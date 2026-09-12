import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';

void main() {
  group('CropRecord', () {
    final base = {
      'id': 'crop_1',
      'farmId': 'farm_1',
      'cropName': 'Rice',
      'variety': 'Basmati',
      'category': 'Cereal',
      'duration': '100-120 days',
      'plantingDate': '2026-06-10T00:00:00.000',
      'expectedHarvestDate': '2026-10-08T00:00:00.000',
      'status': 'active',
      'endReason': null,
      'endDate': null,
      'notes': 'AI-recommended crop plan',
      'recommendationScore': 86.0,
      'recommendationSource': 'ai',
      'cropPlanId': 'plan_crop_1',
    };

    test('fromMap/toMap round-trips all new planning fields', () {
      final crop = CropRecord.fromMap(base);
      expect(crop.isActive, isTrue);
      expect(crop.recommendationScore, 86.0);
      expect(crop.recommendationSource, 'ai');
      expect(crop.cropPlanId, 'plan_crop_1');
      expect(crop.plantingDate, DateTime(2026, 6, 10));
      final map = crop.toMap();
      expect(map['status'], 'active');
      expect(map['plantingDate'], contains('2026-06-10'));
      expect(map['recommendationScore'], 86.0);
      expect(map['recommendationSource'], 'ai');
      expect(map['cropPlanId'], 'plan_crop_1');
    });

    test('history statuses are not active', () {
      for (final s in CropRecord.historyStatuses) {
        expect(CropRecord.fromMap({...base, 'status': s}).isActive, isFalse);
      }
    });

    test('copyWith can mark history and can clear the end fields', () {
      final active = CropRecord.fromMap(base);
      final ended = active.copyWith(
        status: 'harvested',
        endReason: 'good yield',
        endDate: DateTime(2026, 10, 9),
      );
      expect(ended.status, 'harvested');
      expect(ended.isActive, isFalse);
      expect(ended.endReason, 'good yield');
      expect(ended.endDate, isNotNull);
      final cleared = ended.copyWith(clearEnd: true);
      expect(cleared.endReason, isNull);
      expect(cleared.endDate, isNull);
    });
  });

  group('CropSetupQuestionnaire', () {
    test('round-trips including budget', () {
      final q = CropSetupQuestionnaire(
        waterAvailability: 'Medium',
        soilType: 'Loam',
        irrigationSystem: 'Drip',
        farmLocation: 'Pune',
        currentSeason: 'Kharif',
        cropDurationPreference: 'Short',
        cropCategoryPreference: 'Vegetable',
        budgetInrPerAcre: 25000,
      );
      final m = q.toMap();
      expect(m['budgetInrPerAcre'], 25000);
      final restored = CropSetupQuestionnaire.fromMap(m);
      expect(restored.budgetInrPerAcre, 25000);
      expect(restored.currentSeason, 'Kharif');
    });

    test('budget is null when absent', () {
      final restored =
          CropSetupQuestionnaire.fromMap({'waterAvailability': 'Low'});
      expect(restored.budgetInrPerAcre, isNull);
    });
  });

  group('CropTask', () {
    test('toMap/fromMap round-trip', () {
      final task = CropTask(
        id: 'task_1',
        cropId: 'crop_1',
        cropName: 'Rice',
        stage: 'Vegetative Growth',
        type: 'water',
        priority: 'high',
        title: 'Irrigate the crop as per schedule',
        description: '3 inches depth',
        dueDate: DateTime(2026, 7, 10),
        status: 'pending',
        source: 'crop_plan',
      );
      final restored = CropTask.fromMap(task.toMap());
      expect(restored.id, task.id);
      expect(restored.cropId, task.cropId);
      expect(restored.type, 'water');
      expect(restored.priority, 'high');
      expect(restored.dueDate, task.dueDate);
      expect(restored.description, '3 inches depth');
      expect(restored.source, 'crop_plan');
    });

    test('isDueToday and isOverdue helpers', () {
      final today = DateTime.now();
      final past = DateTime.now().subtract(const Duration(days: 2));
      expect(
          CropTask(
                  id: 'a',
                  cropId: 'c',
                  cropName: 'Rice',
                  stage: '',
                  type: 'monitor',
                  priority: 'low',
                  title: 't',
                  dueDate: today)
              .isDueToday,
          isTrue);
      expect(
          CropTask(
                  id: 'a',
                  cropId: 'c',
                  cropName: 'Rice',
                  stage: '',
                  type: 'monitor',
                  priority: 'low',
                  title: 't',
                  dueDate: past)
              .isOverdue,
          isTrue);
      final done = CropTask(
          id: 'a',
          cropId: 'c',
          cropName: 'Rice',
          stage: '',
          type: 'monitor',
          priority: 'low',
          title: 't',
          dueDate: past,
          status: 'done');
      expect(done.isOverdue, isFalse);
    });

    test('copyWith updates status only', () {
      final task = CropTask(
          id: 'a',
          cropId: 'c',
          cropName: 'Rice',
          stage: '',
          type: 'monitor',
          priority: 'low',
          title: 't',
          dueDate: DateTime(2026, 1, 1));
      final done = task.copyWith(status: 'done');
      expect(done.status, 'done');
      expect(done.id, task.id);
      expect(done.title, task.title);
    });
  });

  group('CropBudgetEstimate', () {
    test('classification helpers', () {
      const within = CropBudgetEstimate(
          classification: 'Within',
          cultivationCostMin: 1,
          cultivationCostMax: 2,
          seedCostMin: 1,
          seedCostMax: 2,
          budgetInrPerAcre: 30000);
      const above = CropBudgetEstimate(
          classification: 'Far Above',
          cultivationCostMin: 1,
          cultivationCostMax: 2,
          seedCostMin: 1,
          seedCostMax: 2);
      const unset = CropBudgetEstimate(
          classification: 'Not Specified',
          cultivationCostMin: 0,
          cultivationCostMax: 0,
          seedCostMin: 0,
          seedCostMax: 0);
      expect(within.isWithinBudget, isTrue);
      expect(within.isSpecified, isTrue);
      expect(within.budgetInrPerAcre, 30000);
      expect(above.isWithinBudget, isFalse);
      expect(above.isSpecified, isTrue);
      expect(unset.isSpecified, isFalse);
    });

    test('toMap/fromMap round-trip', () {
      const est = CropBudgetEstimate(
          classification: 'Slightly Above',
          cultivationCostMin: 31000,
          cultivationCostMax: 34000,
          seedCostMin: 3000,
          seedCostMax: 5000,
          budgetInrPerAcre: 25000);
      final restored = CropBudgetEstimate.fromMap(est.toMap());
      expect(restored.classification, 'Slightly Above');
      expect(restored.cultivationCostMax, 34000);
      expect(restored.budgetInrPerAcre, 25000);
    });
  });

  group('CropRecommendationResult', () {
    test('parses a server-shaped nested map', () {
      final result = CropRecommendationResult.fromMap({
        'rank': 1,
        'entry': {
          'id': 'crop_rice',
          'name': 'Rice',
          'varieties': ['Basmati', 'Pusa 1121'],
          'category': 'Cereal',
          'season': 'Kharif',
          'durationDaysMin': 100,
          'durationDaysMax': 120,
          'risks': ['Lodging'],
          'commonPests': ['Stem borer'],
          'commonDiseases': ['Blast'],
          'marketDemand': 'High',
          'riskLevel': 'Medium',
          'description': 'Staple cereal.',
        },
        'score': 86,
        'confidence': 'High',
        'budget': {
          'classification': 'Within',
          'cultivationCostMin': 20000,
          'cultivationCostMax': 30000,
          'seedCostMin': 2000,
          'seedCostMax': 4000,
          'budgetInrPerAcre': 28000,
        },
        'money': {
          'yieldMin': 20,
          'yieldMax': 25,
          'yieldUnit': 'q/acre',
          'revenueMin': 70000,
          'revenueMax': 85000,
          'profitMin': 30000,
          'profitMax': 45000,
        },
        'factors': [
          {'name': 'Climate', 'weight': 3, 'score': 0.9, 'detail': 'Good fit.'},
        ],
        'strengths': ['High demand'],
        'concerns': ['Needs water'],
        'waterNotes': 'High water need.',
        'plantingWindow': 'June-July',
        'harvestHint': 'Oct-Nov',
      });
      expect(result.cropId, 'crop_rice');
      expect(result.cropName, 'Rice');
      expect(result.rank, 1);
      expect(result.score, 86);
      expect(result.varieties, ['Basmati', 'Pusa 1121']);
      expect(result.durationLabel, '100–120 days');
      expect(result.isWithinBudget, isTrue);
      expect(result.factors.single.name, 'Climate');
      expect(result.strengths, ['High demand']);
      expect(result.money.yieldUnit, 'q/acre');
      expect(result.estimatedLabel, isTrue);
    });

    test('toMap/fromMap round-trip preserves structure', () {
      final rec = CropRecommendationResult(
        rank: 2,
        cropId: 'crop_maize',
        cropName: 'Maize',
        varieties: const ['Hybrid'],
        category: 'Cereal',
        season: 'Rabi',
        durationMin: 90,
        durationMax: 110,
        score: 74,
        confidence: 'Medium',
        budget: const CropBudgetEstimate(
            classification: 'Within',
            cultivationCostMin: 18000,
            cultivationCostMax: 26000,
            seedCostMin: 2500,
            seedCostMax: 4000),
        money: const CropMoneyEstimate(
            yieldMin: 18,
            yieldMax: 22,
            yieldUnit: 'q/acre',
            revenueMin: 54000,
            revenueMax: 66000,
            profitMin: 20000,
            profitMax: 30000),
        factors: const [
          RecommendationFactor(name: 'Soil', weight: 2, score: 0.8, detail: '')
        ],
        strengths: const ['Fast growing'],
        concerns: const [],
        waterNotes: 'Medium',
        plantingWindow: 'Dec-Jan',
        harvestHint: 'Apr-May',
        risks: const [],
        pests: const [],
        diseases: const [],
        marketDemand: 'Medium',
        riskLevel: 'Low',
        description: '',
        estimatedLabel: true,
      );
      final restored = CropRecommendationResult.fromMap(rec.toMap());
      expect(restored.rank, 2);
      expect(restored.cropName, 'Maize');
      expect(restored.score, 74);
      expect(restored.budget.classification, 'Within');
      expect(restored.factors.single.name, 'Soil');
    });

    test('empty entry falls back to defaults', () {
      final result = CropRecommendationResult.fromMap({
        'rank': 1,
        'cropId': 'x',
        'cropName': 'X',
      });
      expect(result.estimatedLabel, isTrue);
      expect(result.factors, isEmpty);
      expect(result.varieties, isEmpty);
    });
  });

  group('RecommendationRecord', () {
    test('round-trips top10 snapshot', () {
      final inner = CropRecommendationResult(
        rank: 1,
        cropId: 'c',
        cropName: 'Crop',
        varieties: const [],
        category: '',
        season: '',
        durationMin: 0,
        durationMax: 0,
        score: 50,
        confidence: 'Low',
        budget: const CropBudgetEstimate(
            classification: 'Not Specified',
            cultivationCostMin: 0,
            cultivationCostMax: 0,
            seedCostMin: 0,
            seedCostMax: 0),
        money: const CropMoneyEstimate(
            yieldMin: 0,
            yieldMax: 0,
            yieldUnit: '',
            revenueMin: 0,
            revenueMax: 0,
            profitMin: 0,
            profitMax: 0),
        factors: const [],
        strengths: const [],
        concerns: const [],
        waterNotes: '',
        plantingWindow: '',
        harvestHint: '',
        risks: const [],
        pests: const [],
        diseases: const [],
        marketDemand: '',
        riskLevel: '',
        description: '',
        estimatedLabel: true,
      );
      final record = RecommendationRecord(
        id: 'rec_1',
        farmId: 'farm_1',
        state: 'Maharashtra',
        createdAt: DateTime.utc(2026, 6, 5),
        input: const {'soilType': 'Loam'},
        top10: [inner],
        selectedCropId: 'c',
        selectedCropName: 'Crop',
      );
      final restored = RecommendationRecord.fromMap(record.toMap());
      expect(restored.id, 'rec_1');
      expect(restored.farmId, 'farm_1');
      expect(restored.state, 'Maharashtra');
      expect(restored.top10.single.cropId, 'c');
      expect(restored.selectedCropName, 'Crop');
      expect(restored.input['soilType'], 'Loam');
    });
  });

  group('ManualCropCheck', () {
    test('round-trips factors, estimates and verdict', () {
      final check = ManualCropCheck(
        id: 'manual_1',
        farmId: 'farm_1',
        cropName: 'Tomato',
        variety: 'Hybrid 303',
        score: 72,
        verdict: 'Suitable',
        matchedCrop: 'Tomato',
        createdAt: DateTime.utc(2026, 6, 5),
        factors: const [
          ManualCheckFactor(label: 'State fit', verdict: 'Excellent'),
        ],
        estimates: const [
          CheckEstimate(
              label: 'Duration', value: '110-120 days', accuracy: 'Verified'),
        ],
        strengths: const ['Grown in your state'],
        concerns: const [],
        reason: 'Viable option.',
        seasonNotes: 'Best planting: June.',
        regionNotes: 'Grown in Maharashtra.',
        found: true,
      );
      final restored = ManualCropCheck.fromMap(check.toMap());
      expect(restored.cropName, 'Tomato');
      expect(restored.variety, 'Hybrid 303');
      expect(restored.score, 72);
      expect(restored.verdict, 'Suitable');
      expect(restored.factors.single.verdict, 'Excellent');
      expect(restored.estimates.single.accuracy, 'Verified');
      expect(restored.found, isTrue);
    });
  });

  group('CropPlan', () {
    test('round-trips with stages', () {
      final plan = CropPlan(
        id: 'plan_1',
        cropId: 'crop_1',
        farmId: 'farm_1',
        cropName: 'Rice',
        variety: 'Basmati',
        category: 'Cereal',
        durationDays: 120,
        startDate: DateTime.utc(2026, 6, 10),
        estimatedHarvestDate: DateTime.utc(2026, 10, 8),
        source: 'ai',
        recommendationScore: 86,
        whyRecommended: 'High demand.',
        waterNotes: 'High',
        plantingWindow: 'June-July',
        budget: const CropBudgetEstimate(
            classification: 'Within',
            cultivationCostMin: 1,
            cultivationCostMax: 2,
            seedCostMin: 1,
            seedCostMax: 2),
        money: const CropMoneyEstimate(
            yieldMin: 0,
            yieldMax: 0,
            yieldUnit: '',
            revenueMin: 0,
            revenueMax: 0,
            profitMin: 0,
            profitMax: 0),
        stages: const [
          CropStage(
              index: 0,
              name: 'Land Preparation & Sowing',
              startDay: 1,
              endDay: 12),
          CropStage(index: 1, name: 'Harvest', startDay: 108, endDay: 120),
        ],
        createdAt: DateTime.utc(2026, 6, 5),
      );
      final restored = CropPlan.fromMap(plan.toMap());
      expect(restored.id, 'plan_1');
      expect(restored.source, 'ai');
      expect(restored.recommendationScore, 86);
      expect(restored.stages.length, 2);
      expect(restored.stages.first.status, 'upcoming');
      expect(restored.budget.isWithinBudget, isTrue);
    });

    test('stageForDay returns the correct stage', () {
      final plan = CropPlan(
        id: 'plan_1',
        cropId: 'c',
        farmId: 'f',
        cropName: 'Rice',
        variety: '',
        category: '',
        durationDays: 120,
        startDate: DateTime.utc(2026, 6, 10),
        estimatedHarvestDate: DateTime.utc(2026, 10, 8),
        source: 'local',
        recommendationScore: 0,
        waterNotes: '',
        plantingWindow: '',
        budget: const CropBudgetEstimate(
            classification: 'Not Specified',
            cultivationCostMin: 0,
            cultivationCostMax: 0,
            seedCostMin: 0,
            seedCostMax: 0),
        money: const CropMoneyEstimate(
            yieldMin: 0,
            yieldMax: 0,
            yieldUnit: '',
            revenueMin: 0,
            revenueMax: 0,
            profitMin: 0,
            profitMax: 0),
        stages: const [
          CropStage(index: 0, name: 'A', startDay: 1, endDay: 10),
          CropStage(index: 1, name: 'B', startDay: 11, endDay: 20),
        ],
        createdAt: DateTime.utc(2026, 6, 5),
      );
      expect(plan.stageForDay(DateTime.utc(2026, 6, 12)), isNotNull);
      expect(plan.stageForDay(DateTime.utc(2026, 6, 12))!.name, 'A');
      expect(plan.stageForDay(DateTime.utc(2026, 6, 22))!.name, 'B');
      expect(plan.stageForDay(DateTime.utc(2026, 6, 5)), isNull);
      expect(plan.stageForDay(DateTime.utc(2027, 1, 1))!.name, 'B');
    });
  });

  group('CropCatalogItem', () {
    test('fromMap maps server search results', () {
      final item = CropCatalogItem.fromMap({
        'id': 'crop_tomato',
        'name': 'Tomato',
        'category': 'Vegetable',
        'varieties': ['Hybrid 303'],
        'season': 'Kharif',
        'waterRequirement': 'High',
        'marketDemand': 'High',
        'riskLevel': 'Medium',
        'description': 'Popular vegetable.',
      });
      expect(item.id, 'crop_tomato');
      expect(item.name, 'Tomato');
      expect(item.varieties, ['Hybrid 303']);
      expect(item.marketDemand, 'High');
    });
  });

  group('CropMoneyEstimate', () {
    test('toMap/fromMap round-trip', () {
      const money = CropMoneyEstimate(
          yieldMin: 20,
          yieldMax: 25,
          yieldUnit: 'q/acre',
          revenueMin: 70000,
          revenueMax: 85000,
          profitMin: 30000,
          profitMax: 45000);
      final restored = CropMoneyEstimate.fromMap(money.toMap());
      expect(restored.yieldMin, 20);
      expect(restored.revenueMax, 85000);
      expect(restored.profitMin, 30000);
      expect(restored.yieldUnit, 'q/acre');
    });
  });
}
