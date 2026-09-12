/// Models for the crop-planning feature: crop plans, dated to-do tasks,
/// manual-crop-check results and recommendation run records.
///
/// All persisted objects follow the app convention: Firestore documents plus
/// local SharedPreferences mirrors (offline-first). Money/yield figures are
/// always estimates (server reference ranges) and are labelled as such in UIs.
library;

class CropTask {
  final String id;
  final String cropId;
  final String cropName;
  final String stage;
  final String
      type; // water | nutrition | weed | pest | land | planting | harvest | monitor
  final String priority; // high | medium | low
  final String title;
  final String? description;
  final DateTime dueDate;
  final String status; // pending | done | skipped
  final String source; // crop_plan | manual

  const CropTask({
    required this.id,
    required this.cropId,
    required this.cropName,
    required this.stage,
    required this.type,
    required this.priority,
    required this.title,
    required this.dueDate,
    this.description,
    this.status = 'pending',
    this.source = 'crop_plan',
  });

  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  bool get isOverdue =>
      !status.contains('done') && dueDate.isBefore(DateTime.now());

  CropTask copyWith({String? status}) => CropTask(
        id: id,
        cropId: cropId,
        cropName: cropName,
        stage: stage,
        type: type,
        priority: priority,
        title: title,
        description: description,
        dueDate: dueDate,
        status: status ?? this.status,
        source: source,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'cropId': cropId,
        'cropName': cropName,
        'stage': stage,
        'type': type,
        'priority': priority,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'status': status,
        'source': source,
      };

  factory CropTask.fromMap(Map<String, dynamic> m) => CropTask(
        id: m['id'] ?? '',
        cropId: m['cropId'] ?? '',
        cropName: m['cropName'] ?? '',
        stage: m['stage'] ?? '',
        type: m['type'] ?? 'monitor',
        priority: m['priority'] ?? 'medium',
        title: m['title'] ?? '',
        description: m['description'],
        dueDate: m['dueDate'] != null
            ? DateTime.parse(m['dueDate'])
            : DateTime.now(),
        status: m['status'] ?? 'pending',
        source: m['source'] ?? 'crop_plan',
      );
}

class CropStage {
  final int index;
  final String name; // stage template name
  final int startDay;
  final int endDay;
  final String status; // upcoming | in_progress | completed

  const CropStage({
    required this.index,
    required this.name,
    required this.startDay,
    required this.endDay,
    this.status = 'upcoming',
  });

  CropStage copyWith({String? status}) => CropStage(
      index: index,
      name: name,
      startDay: startDay,
      endDay: endDay,
      status: status ?? this.status);

  Map<String, dynamic> toMap() => {
        'index': index,
        'name': name,
        'startDay': startDay,
        'endDay': endDay,
        'status': status
      };

  factory CropStage.fromMap(Map<String, dynamic> m) => CropStage(
        index: (m['index'] as num?)?.toInt() ?? 0,
        name: m['name'] ?? '',
        startDay: (m['startDay'] as num?)?.toInt() ?? 0,
        endDay: (m['endDay'] as num?)?.toInt() ?? 0,
        status: m['status'] ?? 'upcoming',
      );
}

class CropBudgetEstimate {
  final String
      classification; // Within | Slightly Above | Far Above | Not Specified
  final int cultivationCostMin;
  final int cultivationCostMax;
  final int seedCostMin;
  final int seedCostMax;
  final int? budgetInrPerAcre;

  const CropBudgetEstimate({
    required this.classification,
    required this.cultivationCostMin,
    required this.cultivationCostMax,
    required this.seedCostMin,
    required this.seedCostMax,
    this.budgetInrPerAcre,
  });

  Map<String, dynamic> toMap() => {
        'classification': classification,
        'cultivationCostMin': cultivationCostMin,
        'cultivationCostMax': cultivationCostMax,
        'seedCostMin': seedCostMin,
        'seedCostMax': seedCostMax,
        'budgetInrPerAcre': budgetInrPerAcre,
      };

  factory CropBudgetEstimate.fromMap(Map<String, dynamic> m) =>
      CropBudgetEstimate(
        classification: m['classification'] ?? 'Not Specified',
        cultivationCostMin: (m['cultivationCostMin'] as num?)?.toInt() ?? 0,
        cultivationCostMax: (m['cultivationCostMax'] as num?)?.toInt() ?? 0,
        seedCostMin: (m['seedCostMin'] as num?)?.toInt() ?? 0,
        seedCostMax: (m['seedCostMax'] as num?)?.toInt() ?? 0,
        budgetInrPerAcre: (m['budgetInrPerAcre'] as num?)?.toInt(),
      );

  bool get isWithinBudget => classification == 'Within';
  bool get isSpecified => classification != 'Not Specified';
}

class CropMoneyEstimate {
  final int yieldMin;
  final int yieldMax;
  final String yieldUnit;
  final int revenueMin;
  final int revenueMax;
  final int profitMin;
  final int profitMax;

  const CropMoneyEstimate({
    required this.yieldMin,
    required this.yieldMax,
    required this.yieldUnit,
    required this.revenueMin,
    required this.revenueMax,
    required this.profitMin,
    required this.profitMax,
  });

  Map<String, dynamic> toMap() => {
        'yieldMin': yieldMin,
        'yieldMax': yieldMax,
        'yieldUnit': yieldUnit,
        'revenueMin': revenueMin,
        'revenueMax': revenueMax,
        'profitMin': profitMin,
        'profitMax': profitMax,
      };

  factory CropMoneyEstimate.fromMap(Map<String, dynamic> m) =>
      CropMoneyEstimate(
        yieldMin: (m['yieldMin'] as num?)?.toInt() ?? 0,
        yieldMax: (m['yieldMax'] as num?)?.toInt() ?? 0,
        yieldUnit: m['yieldUnit'] ?? '',
        revenueMin: (m['revenueMin'] as num?)?.toInt() ?? 0,
        revenueMax: (m['revenueMax'] as num?)?.toInt() ?? 0,
        profitMin: (m['profitMin'] as num?)?.toInt() ?? 0,
        profitMax: (m['profitMax'] as num?)?.toInt() ?? 0,
      );
}

/// One line of the estimated per-acre cost breakdown (always labelled as an
/// estimate in UIs; shares express how total cultivation cost is split).
class CropCostLine {
  final String label; // seed | fertilizer | pesticide | labour | irrigation | machinery | other
  final double amountPerAcre;
  final double sharePct;

  const CropCostLine({
    required this.label,
    required this.amountPerAcre,
    required this.sharePct,
  });

  Map<String, dynamic> toMap() =>
      {'label': label, 'amountPerAcre': amountPerAcre, 'sharePct': sharePct};

  factory CropCostLine.fromMap(Map<String, dynamic> m) => CropCostLine(
        label: m['label'] ?? '',
        amountPerAcre: (m['amountPerAcre'] as num?)?.toDouble() ?? 0,
        sharePct: (m['sharePct'] as num?)?.toDouble() ?? 0,
      );
}

class RecommendationFactor {
  final String name;
  final int weight;
  final double score; // 0..1
  final String detail;

  const RecommendationFactor({
    required this.name,
    required this.weight,
    required this.score,
    required this.detail,
  });

  Map<String, dynamic> toMap() =>
      {'name': name, 'weight': weight, 'score': score, 'detail': detail};

  factory RecommendationFactor.fromMap(Map<String, dynamic> m) =>
      RecommendationFactor(
        name: m['name'] ?? '',
        weight: (m['weight'] as num?)?.toInt() ?? 0,
        score: (m['score'] as num?)?.toDouble() ?? 0,
        detail: m['detail'] ?? '',
      );
}

/// A single top-10 recommendation card (structured server data + optional AI
/// narrative added client-side).
class CropRecommendationResult {
  final int rank;
  final String cropId;
  final String cropName;
  final List<String> varieties;
  final String category;
  final String season;
  final int durationMin;
  final int durationMax;
  final int score;
  final String confidence;
  final CropBudgetEstimate budget;
  final CropMoneyEstimate money;
  final List<RecommendationFactor> factors;
  final List<String> strengths;
  final List<String> concerns;
  final String waterNotes;
  final String plantingWindow;
  final String harvestHint;
  final List<String> risks;
  final List<String> pests;
  final List<String> diseases;
  final String marketDemand;
  final String riskLevel;
  final String description;
  final bool estimatedLabel;

  // ── Farm-level analytics (client/computed, nullable = not available) ──
  final String? calendarStatus; // unknown | ideal_now | sow_soon | next_window | not_now
  final String? sowingWindow;
  final String? harvestWindowLocal;
  final String? rotationAnalysis;
  final String? previousCrop;
  final String? riskExplanation;
  final int? riskScore;
  final List<CropCostLine>? costBreakdown;
  final double? costPerAcre;
  final double? revenuePerAcre;
  final double? profitPerAcre;
  final double? profitMarginPct;
  final double? farmAreaAcres;
  final double? totalCost;
  final double? totalRevenue;
  final double? totalProfit;
  final double? yieldPerAcreKg;
  final String? weatherAvailability; // available | cached | absent
  final double? marketPricePerKg;
  final String? marketPriceSource;
  final String? marketPriceDate;
  final Map<String, double> scoreComponents;
  final List<String> dataSources;
  final double confidencePct;

  const CropRecommendationResult({
    required this.rank,
    required this.cropId,
    required this.cropName,
    required this.varieties,
    required this.category,
    required this.season,
    required this.durationMin,
    required this.durationMax,
    required this.score,
    required this.confidence,
    required this.budget,
    required this.money,
    required this.factors,
    required this.strengths,
    required this.concerns,
    required this.waterNotes,
    required this.plantingWindow,
    required this.harvestHint,
    required this.risks,
    required this.pests,
    required this.diseases,
    required this.marketDemand,
    required this.riskLevel,
    required this.description,
    required this.estimatedLabel,
    this.calendarStatus,
    this.sowingWindow,
    this.harvestWindowLocal,
    this.rotationAnalysis,
    this.previousCrop,
    this.riskExplanation,
    this.riskScore,
    this.costBreakdown,
    this.costPerAcre,
    this.revenuePerAcre,
    this.profitPerAcre,
    this.profitMarginPct,
    this.farmAreaAcres,
    this.totalCost,
    this.totalRevenue,
    this.totalProfit,
    this.yieldPerAcreKg,
    this.weatherAvailability,
    this.marketPricePerKg,
    this.marketPriceSource,
    this.marketPriceDate,
    this.scoreComponents = const {},
    this.dataSources = const [],
    this.confidencePct = 0,
  });

  String get durationLabel => '$durationMin–$durationMax days';

  bool get isWithinBudget => budget.isWithinBudget;

  factory CropRecommendationResult.fromMap(Map<String, dynamic> m) {
    final entry = (m['entry'] as Map<String, dynamic>?) ?? const {};
    final budget = (m['budget'] as Map<String, dynamic>?) ?? const {};
    final money = (m['money'] as Map<String, dynamic>?) ?? const {};
    return CropRecommendationResult(
      rank: (m['rank'] as num?)?.toInt() ?? 0,
      cropId: entry['id'] ?? m['cropId'] ?? '',
      cropName: entry['name'] ?? m['cropName'] ?? '',
      varieties: (entry['varieties'] as List?)?.cast<String>() ?? const [],
      category: entry['category'] ?? '',
      season: entry['season'] ?? '',
      durationMin: (entry['durationDaysMin'] as num?)?.toInt() ?? 0,
      durationMax: (entry['durationDaysMax'] as num?)?.toInt() ?? 0,
      score: (m['score'] as num?)?.toInt() ?? 0,
      confidence: m['confidence'] ?? 'Low',
      budget: CropBudgetEstimate.fromMap(budget),
      money: CropMoneyEstimate.fromMap(money),
      factors: (m['factors'] as List?)
              ?.map((f) =>
                  RecommendationFactor.fromMap(f as Map<String, dynamic>))
              .toList() ??
          const [],
      strengths: (m['strengths'] as List?)?.cast<String>() ?? const [],
      concerns: (m['concerns'] as List?)?.cast<String>() ?? const [],
      waterNotes: m['waterNotes'] ?? '',
      plantingWindow: m['plantingWindow'] ?? '',
      harvestHint: m['harvestHint'] ?? '',
      risks: (entry['risks'] as List?)?.cast<String>() ?? const [],
      pests: (entry['commonPests'] as List?)?.cast<String>() ?? const [],
      diseases: (entry['commonDiseases'] as List?)?.cast<String>() ?? const [],
      marketDemand: entry['marketDemand'] ?? '',
      riskLevel: entry['riskLevel'] ?? '',
      description: entry['description'] ?? '',
      estimatedLabel: m['estimatedLabel'] ?? true,
      calendarStatus: m['calendarStatus'],
      sowingWindow: m['sowingWindow'],
      harvestWindowLocal: m['harvestWindowLocal'],
      rotationAnalysis: m['rotationAnalysis'],
      previousCrop: m['previousCrop'],
      riskExplanation: m['riskExplanation'],
      riskScore: (m['riskScore'] as num?)?.toInt(),
      costBreakdown: (m['costBreakdown'] as List?)
          ?.map((c) => CropCostLine.fromMap(c as Map<String, dynamic>))
          .toList(),
      costPerAcre: (m['costPerAcre'] as num?)?.toDouble(),
      revenuePerAcre: (m['revenuePerAcre'] as num?)?.toDouble(),
      profitPerAcre: (m['profitPerAcre'] as num?)?.toDouble(),
      profitMarginPct: (m['profitMarginPct'] as num?)?.toDouble(),
      farmAreaAcres: (m['farmAreaAcres'] as num?)?.toDouble(),
      totalCost: (m['totalCost'] as num?)?.toDouble(),
      totalRevenue: (m['totalRevenue'] as num?)?.toDouble(),
      totalProfit: (m['totalProfit'] as num?)?.toDouble(),
      yieldPerAcreKg: (m['yieldPerAcreKg'] as num?)?.toDouble(),
      weatherAvailability: m['weatherAvailability'],
      marketPricePerKg: (m['marketPricePerKg'] as num?)?.toDouble(),
      marketPriceSource: m['marketPriceSource'],
      marketPriceDate: m['marketPriceDate'],
      scoreComponents:
          (m['scoreComponents'] as Map?)?.cast<String, double>() ?? const {},
      dataSources: (m['dataSources'] as List?)?.cast<String>() ?? const [],
      confidencePct: (m['confidencePct'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'rank': rank,
        'cropId': cropId,
        'cropName': cropName,
        'varieties': varieties,
        'category': category,
        'season': season,
        'durationDaysMin': durationMin,
        'durationDaysMax': durationMax,
        'score': score,
        'confidence': confidence,
        'budget': budget.toMap(),
        'money': money.toMap(),
        'factors': factors.map((f) => f.toMap()).toList(),
        'strengths': strengths,
        'concerns': concerns,
        'waterNotes': waterNotes,
        'plantingWindow': plantingWindow,
        'harvestHint': harvestHint,
        'risks': risks,
        'pests': pests,
        'diseases': diseases,
        'marketDemand': marketDemand,
        'riskLevel': riskLevel,
        'description': description,
        'estimatedLabel': estimatedLabel,
        'calendarStatus': calendarStatus,
        'sowingWindow': sowingWindow,
        'harvestWindowLocal': harvestWindowLocal,
        'rotationAnalysis': rotationAnalysis,
        'previousCrop': previousCrop,
        'riskExplanation': riskExplanation,
        'riskScore': riskScore,
        'costBreakdown': costBreakdown?.map((c) => c.toMap()).toList(),
        'costPerAcre': costPerAcre,
        'revenuePerAcre': revenuePerAcre,
        'profitPerAcre': profitPerAcre,
        'profitMarginPct': profitMarginPct,
        'farmAreaAcres': farmAreaAcres,
        'totalCost': totalCost,
        'totalRevenue': totalRevenue,
        'totalProfit': totalProfit,
        'yieldPerAcreKg': yieldPerAcreKg,
        'weatherAvailability': weatherAvailability,
        'marketPricePerKg': marketPricePerKg,
        'marketPriceSource': marketPriceSource,
        'marketPriceDate': marketPriceDate,
        'scoreComponents': scoreComponents,
        'dataSources': dataSources,
        'confidencePct': confidencePct,
      };
}

/// One recommendation run (served top-10 snapshot) persisted for history/comparison.
class RecommendationRecord {
  final String id;
  final String farmId;
  final String state;
  final DateTime createdAt;
  final Map<String, dynamic> input;
  final List<CropRecommendationResult> top10;
  final String? selectedCropId;
  final String? selectedCropName;

  const RecommendationRecord({
    required this.id,
    required this.farmId,
    required this.state,
    required this.createdAt,
    required this.input,
    required this.top10,
    this.selectedCropId,
    this.selectedCropName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'state': state,
        'createdAt': createdAt.toIso8601String(),
        'input': input,
        'top10': top10.map((r) => r.toMap()).toList(),
        'selectedCropId': selectedCropId,
        'selectedCropName': selectedCropName,
      };

  factory RecommendationRecord.fromMap(Map<String, dynamic> m) =>
      RecommendationRecord(
        id: m['id'] ?? '',
        farmId: m['farmId'] ?? '',
        state: m['state'] ?? '',
        createdAt: m['createdAt'] != null
            ? DateTime.parse(m['createdAt'])
            : DateTime.now(),
        input: (m['input'] as Map?)?.cast<String, dynamic>() ?? const {},
        top10: (m['top10'] as List?)
                ?.map((e) =>
                    CropRecommendationResult.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        selectedCropId: m['selectedCropId'],
        selectedCropName: m['selectedCropName'],
      );
}

class ManualCheckFactor {
  final String label;
  final String verdict; // Excellent | Potential Concern | Severe Risk

  const ManualCheckFactor({required this.label, required this.verdict});
}

class CheckEstimate {
  final String label;
  final String value;
  final String accuracy; // Verified | Estimated

  const CheckEstimate(
      {required this.label, required this.value, required this.accuracy});
}

/// Result of a manual crop check against the verified knowledge database.
class ManualCropCheck {
  final String id;
  final String farmId;
  final String cropName;
  final String? variety;
  final int score;
  final String verdict;
  final String matchedCrop;
  final DateTime createdAt;
  final List<ManualCheckFactor> factors;
  final List<CheckEstimate> estimates;
  final List<String> strengths;
  final List<String> concerns;
  final String reason;
  final String seasonNotes;
  final String regionNotes;
  final bool found;

  const ManualCropCheck({
    required this.id,
    required this.farmId,
    required this.cropName,
    required this.variety,
    required this.score,
    required this.verdict,
    required this.matchedCrop,
    required this.createdAt,
    required this.factors,
    required this.estimates,
    required this.strengths,
    required this.concerns,
    required this.reason,
    required this.seasonNotes,
    required this.regionNotes,
    required this.found,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'cropName': cropName,
        'variety': variety,
        'score': score,
        'verdict': verdict,
        'matchedCrop': matchedCrop,
        'createdAt': createdAt.toIso8601String(),
        'factors': factors
            .map((f) => {'label': f.label, 'verdict': f.verdict})
            .toList(),
        'estimates': estimates
            .map((e) =>
                {'label': e.label, 'value': e.value, 'accuracy': e.accuracy})
            .toList(),
        'strengths': strengths,
        'concerns': concerns,
        'reason': reason,
        'seasonNotes': seasonNotes,
        'regionNotes': regionNotes,
        'found': found,
      };

  factory ManualCropCheck.fromMap(Map<String, dynamic> m) => ManualCropCheck(
        id: m['id'] ?? '',
        farmId: m['farmId'] ?? '',
        cropName: m['cropName'] ?? '',
        variety: m['variety'],
        score: (m['score'] as num?)?.toInt() ?? 0,
        verdict: m['verdict'] ?? 'Not Recommended',
        matchedCrop: m['matchedCrop'] ?? '',
        createdAt: m['createdAt'] != null
            ? DateTime.parse(m['createdAt'])
            : DateTime.now(),
        factors: (m['factors'] as List?)
                ?.map((e) => ManualCheckFactor(
                    label: (e as Map<String, dynamic>)['label'] ?? '',
                    verdict: e['verdict'] ?? 'Potential Concern'))
                .toList() ??
            const [],
        estimates: (m['estimates'] as List?)
                ?.map((e) => CheckEstimate(
                    label: (e as Map<String, dynamic>)['label'] ?? '',
                    value: e['value'] ?? '',
                    accuracy: e['accuracy'] ?? 'Estimated'))
                .toList() ??
            const [],
        strengths: (m['strengths'] as List?)?.cast<String>() ?? const [],
        concerns: (m['concerns'] as List?)?.cast<String>() ?? const [],
        reason: m['reason'] ?? '',
        seasonNotes: m['seasonNotes'] ?? '',
        regionNotes: m['regionNotes'] ?? '',
        found: m['found'] ?? true,
      );
}

/// Full plan attached to an active crop (kept on the Crop doc + mirrored).
class CropPlan {
  final String id;
  final String cropId;
  final String farmId;
  final String cropName;
  final String variety;
  final String category;
  final int durationDays;
  final DateTime startDate;
  final DateTime estimatedHarvestDate;
  final String source; // ai | manual | local
  final int recommendationScore;
  final String? whyRecommended; // structured reason (server) or AI narrative
  final String waterNotes;
  final String plantingWindow;
  final CropBudgetEstimate budget;
  final CropMoneyEstimate money;
  final List<CropStage> stages;
  final DateTime createdAt;

  const CropPlan({
    required this.id,
    required this.cropId,
    required this.farmId,
    required this.cropName,
    required this.variety,
    required this.category,
    required this.durationDays,
    required this.startDate,
    required this.estimatedHarvestDate,
    required this.source,
    required this.recommendationScore,
    required this.waterNotes,
    required this.plantingWindow,
    required this.budget,
    required this.money,
    required this.stages,
    required this.createdAt,
    this.whyRecommended,
  });

  CropPlan copyWith({
    String? whyRecommended,
    DateTime? startDate,
    DateTime? estimatedHarvestDate,
  }) =>
      CropPlan(
        id: id,
        cropId: cropId,
        farmId: farmId,
        cropName: cropName,
        variety: variety,
        category: category,
        durationDays: durationDays,
        startDate: startDate ?? this.startDate,
        estimatedHarvestDate: estimatedHarvestDate ?? this.estimatedHarvestDate,
        source: source,
        recommendationScore: recommendationScore,
        whyRecommended: whyRecommended ?? this.whyRecommended,
        waterNotes: waterNotes,
        plantingWindow: plantingWindow,
        budget: budget,
        money: money,
        stages: stages,
        createdAt: createdAt,
      );

  CropStage? stageForDay(DateTime day) {
    final d = day.difference(startDate).inDays + 1;
    if (d < 0) return null;
    for (final s in stages) {
      if (d >= s.startDay && d <= s.endDay) return s;
    }
    return stages.isEmpty ? null : stages.last;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cropId': cropId,
        'farmId': farmId,
        'cropName': cropName,
        'variety': variety,
        'category': category,
        'durationDays': durationDays,
        'startDate': startDate.toIso8601String(),
        'estimatedHarvestDate': estimatedHarvestDate.toIso8601String(),
        'source': source,
        'recommendationScore': recommendationScore,
        'whyRecommended': whyRecommended,
        'waterNotes': waterNotes,
        'plantingWindow': plantingWindow,
        'budget': budget.toMap(),
        'money': money.toMap(),
        'stages': stages.map((s) => s.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory CropPlan.fromMap(Map<String, dynamic> m) => CropPlan(
        id: m['id'] ?? '',
        cropId: m['cropId'] ?? '',
        farmId: m['farmId'] ?? '',
        cropName: m['cropName'] ?? '',
        variety: m['variety'] ?? '',
        category: m['category'] ?? '',
        durationDays: (m['durationDays'] as num?)?.toInt() ?? 0,
        startDate: m['startDate'] != null
            ? DateTime.parse(m['startDate'])
            : DateTime.now(),
        estimatedHarvestDate: m['estimatedHarvestDate'] != null
            ? DateTime.parse(m['estimatedHarvestDate'])
            : DateTime.now(),
        source: m['source'] ?? 'local',
        recommendationScore: (m['recommendationScore'] as num?)?.toInt() ?? 0,
        whyRecommended: m['whyRecommended'],
        waterNotes: m['waterNotes'] ?? '',
        plantingWindow: m['plantingWindow'] ?? '',
        budget: CropBudgetEstimate.fromMap(
            (m['budget'] as Map?)?.cast<String, dynamic>() ?? const {}),
        money: CropMoneyEstimate.fromMap(
            (m['money'] as Map?)?.cast<String, dynamic>() ?? const {}),
        stages: (m['stages'] as List?)
                ?.map((s) =>
                    CropStage.fromMap((s as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        createdAt: m['createdAt'] != null
            ? DateTime.parse(m['createdAt'])
            : DateTime.now(),
      );
}

/// Lightweight searched crop summary from the server catalog.
class CropCatalogItem {
  final String id;
  final String name;
  final String category;
  final List<String> varieties;
  final String season;
  final String waterRequirement;
  final String marketDemand;
  final String riskLevel;
  final String description;

  const CropCatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.varieties,
    required this.season,
    required this.waterRequirement,
    required this.marketDemand,
    required this.riskLevel,
    required this.description,
  });

  factory CropCatalogItem.fromMap(Map<String, dynamic> m) => CropCatalogItem(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        category: m['category'] ?? '',
        varieties: (m['varieties'] as List?)?.cast<String>() ?? const [],
        season: m['season'] ?? '',
        waterRequirement: m['waterRequirement'] ?? '',
        marketDemand: m['marketDemand'] ?? '',
        riskLevel: m['riskLevel'] ?? '',
        description: m['description'] ?? '',
      );
}
