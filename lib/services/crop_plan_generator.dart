import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';

/// Deterministically turns a recommended/manually-checked crop into a dated
/// CropPlan with lifecycle stages and an auto-generated to-do list.
///
/// Rules (tested in test/crop_plan_generator_test.dart):
///  * Stages are derived from crop duration percentages.
///  * Water tasks are generated on a schedule matching the crop water need.
///  * Nutrition/weed/pest/harvest milestones are fixed offsets from planting.
///  * No random values — identical inputs yield identical plans.
class CropPlanGenerator {
  CropPlan buildPlan({
    required FarmProfile farm,
    required CropRecommendationResult recommendation,
    required String cropId,
    DateTime? startDate,
    String? varietyOverride,
  }) {
    final start = _dateOnly(startDate ?? DateTime.now());
    var duration = recommendation.durationMax;
    if (duration <= 0) duration = 120;
    if (duration < recommendation.durationMin) {
      duration = recommendation.durationMin;
    }
    if (duration > 365) duration = 365;
    final harvest = start.add(Duration(days: duration));

    final stages = _buildStages(duration);

    return CropPlan(
      id: 'plan_$cropId',
      cropId: cropId,
      farmId: farm.farmId,
      cropName: recommendation.cropName,
      variety: (varietyOverride != null && varietyOverride.isNotEmpty)
          ? varietyOverride
          : recommendation.varieties.isNotEmpty
              ? recommendation.varieties.first
              : recommendation.cropName,
      category: recommendation.category,
      durationDays: duration,
      startDate: start,
      estimatedHarvestDate: harvest,
      source: 'ai',
      recommendationScore: recommendation.score,
      whyRecommended: recommendation.strengths.isNotEmpty
          ? recommendation.strengths.join('. ')
          : null,
      waterNotes: recommendation.waterNotes,
      plantingWindow: recommendation.plantingWindow,
      budget: recommendation.budget,
      money: recommendation.money,
      stages: stages,
      createdAt: DateTime.now(),
    );
  }

  List<CropTask> buildTasks(CropPlan plan) {
    final tasks = <CropTask>[];
    final start = _dateOnly(plan.startDate);

    void add(int day, String type, String priority, String title,
        {String? desc}) {
      final id = '${plan.cropId}_d${day}_${type}_${tasks.length}';
      tasks.add(CropTask(
        id: id,
        cropId: plan.cropId,
        cropName: plan.cropName,
        stage: _stageNameForDay(plan, day),
        type: type,
        priority: priority,
        title: title,
        description: desc,
        dueDate: start.add(Duration(days: day - 1)),
        source: 'crop_plan',
      ));
    }

    // Land preparation + sowing
    add(1, 'land', 'high', 'Prepare the field and level the soil');
    add(1, 'planting', 'high', 'Sow or transplant at recommended spacing');
    add(1, 'nutrition', 'high', 'Apply basal fertilizer at sowing time');

    // Water schedule (deterministic cadence based on water need)
    final requirement = plan.waterNotes.toLowerCase();
    final cadence = requirement.contains('high')
        ? 7
        : requirement.contains('low')
            ? 14
            : 10;
    var day = cadence;
    while (day < plan.durationDays - 7) {
      add(day, 'water', 'high', 'Irrigate the crop as per schedule');
      day += cadence;
    }

    // Nutrition milestone
    add(30, 'nutrition', 'medium',
        'Apply top dressing (urea / DAP) if crop is behind');

    // Weed control
    add(25, 'weed', 'medium', 'Carry out weeding / weed control');
    add(45, 'weed', 'medium', 'Second weeding round');

    // Pest scouting during critical window
    final criticalStart = (plan.durationDays * 0.55).round();
    for (var i = 0; i < 3; i++) {
      final d = criticalStart + (i * 10);
      if (d < plan.durationDays - 5) {
        add(d, 'pest', 'high', 'Scout for pests and diseases');
      }
    }

    // Harvest window
    final harvestDay = (plan.durationDays * 0.9).round();
    add(harvestDay, 'harvest', 'high', 'Harvest at optimum maturity');
    add(harvestDay + 2, 'harvest', 'medium', 'Thresh and dry produce properly');

    tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return tasks;
  }

  List<CropStage> _buildStages(int duration) {
    List<CropStage> from(int a, int b, String name) => [
          CropStage(
            index: 0,
            name: name,
            startDay: (duration * a / 100).round().clamp(1, duration),
            endDay: (duration * b / 100).round().clamp(1, duration),
          )
        ];
    final stages = <CropStage>[
      ...from(1, 10, 'Land Preparation & Sowing'),
      ...from(10, 20, 'Germination / Establishment'),
      ...from(20, 55, 'Vegetative Growth'),
      ...from(55, 80, 'Critical / Flowering Stage'),
      ...from(80, 95, 'Maturity'),
      ...from(90, 100, 'Harvest'),
    ];
    for (var i = 0; i < stages.length; i++) {
      stages[i] = CropStage(
          index: i,
          name: stages[i].name,
          startDay: stages[i].startDay,
          endDay: stages[i].endDay);
    }
    return stages;
  }

  String _stageNameForDay(CropPlan plan, int day) {
    for (final s in plan.stages) {
      if (day >= s.startDay && day <= s.endDay) return s.name;
    }
    return 'Harvest';
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
