import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/services/crop_plan_generator.dart';

void main() {
  final farm = FarmProfile(
    farmId: 'farm_1',
    index: 0,
    farmName: 'Main field',
    farmSize: '2.5',
    farmLocation: const AddressData(
      fullAddress: 'Pune road',
      district: 'Pune',
      state: 'Maharashtra',
    ),
    soilType: 'Loam',
    irrigationType: 'Drip',
    waterAvailability: 'Medium',
    farmingMethod: 'Organic',
  );

  CropRecommendationResult recommendation(
      {String waterNotes = 'High water need'}) {
    return CropRecommendationResult(
      rank: 1,
      cropId: 'crop_rice',
      cropName: 'Rice',
      varieties: const ['Basmati'],
      category: 'Cereal',
      season: 'Kharif',
      durationMin: 100,
      durationMax: 120,
      score: 86,
      confidence: 'High',
      budget: const CropBudgetEstimate(
        classification: 'Within',
        cultivationCostMin: 20000,
        cultivationCostMax: 30000,
        seedCostMin: 2000,
        seedCostMax: 4000,
        budgetInrPerAcre: 28000,
      ),
      money: const CropMoneyEstimate(
        yieldMin: 20,
        yieldMax: 25,
        yieldUnit: 'quintal/acre',
        revenueMin: 70000,
        revenueMax: 85000,
        profitMin: 30000,
        profitMax: 45000,
      ),
      factors: const [
        RecommendationFactor(
          name: 'Climate',
          weight: 3,
          score: 0.9,
          detail: 'Matches monsoon climate.',
        ),
      ],
      strengths: const ['High market demand'],
      concerns: const ['Needs reliable water'],
      waterNotes: waterNotes,
      plantingWindow: 'June–July',
      harvestHint: 'October–November',
      risks: const ['Heavy rain lodging'],
      pests: const ['Stem borer'],
      diseases: const ['Blast'],
      marketDemand: 'High',
      riskLevel: 'Medium',
      description: 'Staple cereal for the region.',
      estimatedLabel: true,
    );
  }

  group('CropPlanGenerator.buildPlan', () {
    test('id, cropId and farmId are wired correctly', () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      expect(plan.id, 'plan_plant_1');
      expect(plan.cropId, 'plant_1');
      expect(plan.farmId, 'farm_1');
      expect(plan.cropName, 'Rice');
    });

    test('duration and harvest date derive from the recommendation', () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      expect(plan.durationDays, 120);
      expect(plan.startDate, DateTime(2026, 6, 10));
      expect(plan.estimatedHarvestDate, DateTime(2026, 10, 8));
    });

    test('duration is clamped to a sensible range', () {
      final rec = recommendation();
      final long = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: CropRecommendationResult(
          rank: 1,
          cropId: rec.cropId,
          cropName: rec.cropName,
          varieties: rec.varieties,
          category: rec.category,
          season: rec.season,
          durationMin: 400,
          durationMax: 500,
          score: rec.score,
          confidence: rec.confidence,
          budget: rec.budget,
          money: rec.money,
          factors: rec.factors,
          strengths: rec.strengths,
          concerns: rec.concerns,
          waterNotes: rec.waterNotes,
          plantingWindow: rec.plantingWindow,
          harvestHint: rec.harvestHint,
          risks: rec.risks,
          pests: rec.pests,
          diseases: rec.diseases,
          marketDemand: rec.marketDemand,
          riskLevel: rec.riskLevel,
          description: rec.description,
          estimatedLabel: rec.estimatedLabel,
        ),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      expect(long.durationDays, 365);
    });

    test('variety override wins over the recommended varieties', () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(),
        cropId: 'plant_1',
        varietyOverride: 'Pusa Basmati 1121',
        startDate: DateTime(2026, 6, 10),
      );
      expect(plan.variety, 'Pusa Basmati 1121');
    });

    test('six lifecycle stages are generated in order with sane boundaries',
        () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      expect(plan.stages.length, 6);
      expect(plan.stages.map((s) => s.name), [
        'Land Preparation & Sowing',
        'Germination / Establishment',
        'Vegetative Growth',
        'Critical / Flowering Stage',
        'Maturity',
        'Harvest',
      ]);
      for (var i = 0; i < plan.stages.length; i++) {
        final s = plan.stages[i];
        expect(s.index, i);
        expect(s.startDay, greaterThanOrEqualTo(1));
        expect(s.endDay, greaterThanOrEqualTo(s.startDay));
        expect(s.endDay, lessThanOrEqualTo(plan.durationDays));
      }
      expect(plan.stages.last.endDay, plan.durationDays);
      expect(plan.stages.first.startDay, 1);
    });

    test(
        'stageForDay resolves the correct stage, null before start, last after end',
        () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      expect(plan.stageForDay(DateTime(2026, 6, 12)), plan.stages[0]);
      expect(plan.stageForDay(DateTime(2026, 6, 5)), isNull);
      expect(plan.stageForDay(DateTime(2026, 11, 1)), plan.stages.last);
    });

    test('identical inputs produce identical plans (deterministic)', () {
      CropPlan plan() => CropPlanGenerator().buildPlan(
            farm: farm,
            recommendation: recommendation(),
            cropId: 'plant_1',
            startDate: DateTime(2026, 6, 10),
          );
      final a = plan();
      final b = plan();
      final aMap = a.toMap()..remove('createdAt');
      final bMap = b.toMap()..remove('createdAt');
      expect(aMap, bMap);
    });
  });

  group('CropPlanGenerator.buildTasks', () {
    test('contains planting milestones at the start and end of the cycle', () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      final tasks = CropPlanGenerator().buildTasks(plan);
      expect(
        tasks.where((t) => t.type == 'harvest').length,
        greaterThanOrEqualTo(2),
      );
      expect(
        tasks.where((t) => t.type == 'planting' || t.type == 'land').length,
        greaterThanOrEqualTo(2),
      );
      expect(tasks.first.dueDate, plan.startDate);
    });

    test('water tasks follow a cadence matching the water need', () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(waterNotes: 'High water requirement'),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      final tasks = CropPlanGenerator().buildTasks(plan);
      final water = tasks.where((t) => t.type == 'water').toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      expect(water, isNotEmpty);
      for (var i = 1; i < water.length; i++) {
        final gap = water[i].dueDate.difference(water[i - 1].dueDate).inDays;
        expect(gap, lessThanOrEqualTo(8),
            reason: 'high-water cadence is ~7 days');
      }
    });

    test('every task is sorted by due date and holds valid metadata', () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      final tasks = CropPlanGenerator().buildTasks(plan);
      for (var i = 1; i < tasks.length; i++) {
        expect(
          tasks[i].dueDate.isBefore(tasks[i - 1].dueDate),
          isFalse,
        );
      }
      for (final t in tasks) {
        expect(t.title, isNotEmpty);
        expect(['high', 'medium', 'low'], contains(t.priority));
        expect(t.status, 'pending');
        expect(t.source, 'crop_plan');
        expect(t.cropId, 'plant_1');
      }
    });

    test('task ids are unique', () {
      final plan = CropPlanGenerator().buildPlan(
        farm: farm,
        recommendation: recommendation(),
        cropId: 'plant_1',
        startDate: DateTime(2026, 6, 10),
      );
      final tasks = CropPlanGenerator().buildTasks(plan);
      final ids = tasks.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('identical plans yield identical task lists (deterministic)', () {
      CropPlan plan() => CropPlanGenerator().buildPlan(
            farm: farm,
            recommendation: recommendation(),
            cropId: 'plant_1',
            startDate: DateTime(2026, 6, 10),
          );
      final a = CropPlanGenerator().buildTasks(plan());
      final b = CropPlanGenerator().buildTasks(plan());
      expect(
          a.map((t) => t.toMap()).toList(), b.map((t) => t.toMap()).toList());
    });
  });
}
