import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/locale/locale.dart';

/// A single date-bounded record of a crop grown on the farm.
class CropRecord {
  final String id;
  final String farmId;
  final String cropName;
  final String variety;
  final String category;
  final String duration;
  final DateTime plantingDate;
  final DateTime? expectedHarvestDate;
  final String
      status; // active, harvested, completed, stopped, abandoned, failed
  final String? endReason;
  final DateTime? endDate;
  final String? notes;
  final double? recommendationScore;
  final String? recommendationSource; // ai | manual | local
  final String? cropPlanId;

  static const List<String> activeStatuses = ['active'];
  static const List<String> historyStatuses = [
    'harvested',
    'completed',
    'stopped',
    'abandoned',
    'failed',
  ];

  bool get isActive => activeStatuses.contains(status);

  CropRecord({
    required this.id,
    required this.farmId,
    required this.cropName,
    required this.variety,
    required this.category,
    required this.duration,
    required this.plantingDate,
    this.expectedHarvestDate,
    this.status = 'active',
    this.endReason,
    this.endDate,
    this.notes,
    this.recommendationScore,
    this.recommendationSource,
    this.cropPlanId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'cropName': cropName,
        'variety': variety,
        'category': category,
        'duration': duration,
        'plantingDate': plantingDate.toIso8601String(),
        'expectedHarvestDate': expectedHarvestDate?.toIso8601String(),
        'status': status,
        'endReason': endReason,
        'endDate': endDate?.toIso8601String(),
        'notes': notes,
        'recommendationScore': recommendationScore,
        'recommendationSource': recommendationSource,
        'cropPlanId': cropPlanId,
      };

  factory CropRecord.fromMap(Map<String, dynamic> m) => CropRecord(
        id: m['id'] ?? '',
        farmId: m['farmId'] ?? '',
        cropName: m['cropName'] ?? '',
        variety: m['variety'] ?? '',
        category: m['category'] ?? '',
        duration: m['duration'] ?? '',
        plantingDate: m['plantingDate'] != null
            ? DateTime.parse(m['plantingDate'])
            : DateTime.now(),
        expectedHarvestDate: m['expectedHarvestDate'] != null
            ? DateTime.parse(m['expectedHarvestDate'])
            : null,
        status: m['status'] ?? 'active',
        endReason: m['endReason'],
        endDate: m['endDate'] != null ? DateTime.parse(m['endDate']) : null,
        notes: m['notes'],
        recommendationScore: (m['recommendationScore'] as num?)?.toDouble(),
        recommendationSource: m['recommendationSource'],
        cropPlanId: m['cropPlanId'],
      );

  CropRecord copyWith({
    String? cropName,
    String? variety,
    String? status,
    DateTime? expectedHarvestDate,
    String? endReason,
    DateTime? endDate,
    String? notes,
    double? recommendationScore,
    String? recommendationSource,
    String? cropPlanId,
    bool clearEnd = false,
  }) =>
      CropRecord(
          id: id,
          farmId: farmId,
          cropName: cropName ?? this.cropName,
          variety: variety ?? this.variety,
          category: category,
          duration: duration,
          plantingDate: plantingDate,
          expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
          status: status ?? this.status,
          endReason: clearEnd ? null : (endReason ?? this.endReason),
          endDate: clearEnd ? null : (endDate ?? this.endDate),
          notes: notes ?? this.notes,
          recommendationScore: recommendationScore ?? this.recommendationScore,
          recommendationSource:
              recommendationSource ?? this.recommendationSource,
          cropPlanId: cropPlanId ?? this.cropPlanId);
}

class CropSetupQuestionnaire {
  final String lastCrop;
  final String harvestDate;
  final String landIdleDuration;
  final String lastIrrigation;
  final String waterAvailability;
  final String soilType;
  final String soilCondition;
  final String soilFertility;
  final String drainageCondition;
  final String irrigationSystem;
  final String farmLocation;
  final String farmSize;
  final String currentSeason;
  final String cropDurationPreference;
  final String cropCategoryPreference;
  final int? budgetInrPerAcre;
  final String waterSource;
  final String previousCropSowingDate;
  final String previousCropDuration;
  final String seasonalWaterReliability;
  final String farmingPriority;
  final String farmerPreference;

  CropSetupQuestionnaire({
    this.lastCrop = '',
    this.harvestDate = '',
    this.landIdleDuration = '',
    this.lastIrrigation = '',
    this.waterAvailability = '',
    this.soilType = '',
    this.soilCondition = '',
    this.soilFertility = '',
    this.drainageCondition = '',
    this.irrigationSystem = '',
    this.farmLocation = '',
    this.farmSize = '',
    this.currentSeason = '',
    this.cropDurationPreference = '',
    this.cropCategoryPreference = '',
    this.budgetInrPerAcre,
    this.waterSource = '',
    this.previousCropSowingDate = '',
    this.previousCropDuration = '',
    this.seasonalWaterReliability = '',
    this.farmingPriority = '',
    this.farmerPreference = '',
  });

  Map<String, dynamic> toMap() => {
        'lastCrop': lastCrop,
        'harvestDate': harvestDate,
        'landIdleDuration': landIdleDuration,
        'lastIrrigation': lastIrrigation,
        'waterAvailability': waterAvailability,
        'soilType': soilType,
        'soilCondition': soilCondition,
        'soilFertility': soilFertility,
        'drainageCondition': drainageCondition,
        'irrigationSystem': irrigationSystem,
        'farmLocation': farmLocation,
        'farmSize': farmSize,
        'currentSeason': currentSeason,
        'cropDurationPreference': cropDurationPreference,
        'cropCategoryPreference': cropCategoryPreference,
        'budgetInrPerAcre': budgetInrPerAcre,
        'waterSource': waterSource,
        'previousCropSowingDate': previousCropSowingDate,
        'previousCropDuration': previousCropDuration,
        'seasonalWaterReliability': seasonalWaterReliability,
        'farmingPriority': farmingPriority,
        'farmerPreference': farmerPreference,
      };

  factory CropSetupQuestionnaire.fromMap(Map<String, dynamic> m) =>
      CropSetupQuestionnaire(
        lastCrop: m['lastCrop'] ?? '',
        harvestDate: m['harvestDate'] ?? '',
        landIdleDuration: m['landIdleDuration'] ?? '',
        lastIrrigation: m['lastIrrigation'] ?? '',
        waterAvailability: m['waterAvailability'] ?? '',
        soilType: m['soilType'] ?? '',
        soilCondition: m['soilCondition'] ?? '',
        soilFertility: m['soilFertility'] ?? '',
        drainageCondition: m['drainageCondition'] ?? '',
        irrigationSystem: m['irrigationSystem'] ?? '',
        farmLocation: m['farmLocation'] ?? '',
        farmSize: m['farmSize'] ?? '',
        currentSeason: m['currentSeason'] ?? '',
        cropDurationPreference: m['cropDurationPreference'] ?? '',
        cropCategoryPreference: m['cropCategoryPreference'] ?? '',
        budgetInrPerAcre: (m['budgetInrPerAcre'] as num?)?.toInt(),
        waterSource: m['waterSource'] ?? '',
        previousCropSowingDate: m['previousCropSowingDate'] ?? '',
        previousCropDuration: m['previousCropDuration'] ?? '',
        seasonalWaterReliability: m['seasonalWaterReliability'] ?? '',
        farmingPriority: m['farmingPriority'] ?? '',
        farmerPreference: m['farmerPreference'] ?? '',
      );

  /// Returns list of missing MANDATORY fields. Only the ~5 fields the farmer
  /// must enter manually (with the AI recommendation) are mandatory; all other
  /// context (soil, water source, irrigation, history, season, location, ...)
  /// is auto-collected from the stored farm profile and documented sources.
  List<String> getMissingMandatoryFields(AppLocalizations loc) {
    final missing = <String>[];
    if (cropCategoryPreference.trim().isEmpty) missing.add(loc.cropCategoryPreference);
    if (cropDurationPreference.trim().isEmpty) missing.add(loc.cropDurationPreference);
    if (budgetInrPerAcre == null || budgetInrPerAcre! <= 0) missing.add(loc.cropBudgetPerAcre);
    if (waterAvailability.trim().isEmpty) missing.add(loc.currentWaterAvailability);
    if (farmingPriority.trim().isEmpty) missing.add(loc.farmingPriority);
    return missing;
  }

  /// Returns true if all MANDATORY fields are complete (see above).
  bool get isComplete {
    return cropCategoryPreference.trim().isNotEmpty &&
        cropDurationPreference.trim().isNotEmpty &&
        budgetInrPerAcre != null &&
        budgetInrPerAcre! > 0 &&
        waterAvailability.trim().isNotEmpty &&
        farmingPriority.trim().isNotEmpty;
  }
}

class CropRecommendation {
  final String cropId;
  final String cropName;
  final String variety;
  final String category;
  final String duration;
  final String suitableSoil;
  final String waterRequirement;
  final String suitableClimate;
  final String expectedYield;
  final String estimatedInvestment;
  final String expectedRevenue;
  final String potentialProfit;
  final String marketAvailability;
  final String riskLevel;
  final String whyRecommended;
  final String bestPlantingPeriod;
  final String expectedHarvestPeriod;
  final double score;

  final String? calendarStatus;
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
  final String? weatherAvailability;
  final double? marketPricePerKg;
  final String? marketPriceSource;
  final String? marketPriceDate;
  final Map<String, double> scoreComponents;
  final List<String> dataSources;
  final double confidencePct;

  CropRecommendation({
    required this.cropId,
    required this.cropName,
    required this.variety,
    required this.category,
    required this.duration,
    required this.suitableSoil,
    required this.waterRequirement,
    required this.suitableClimate,
    required this.expectedYield,
    required this.estimatedInvestment,
    required this.expectedRevenue,
    required this.potentialProfit,
    required this.marketAvailability,
    required this.riskLevel,
    required this.whyRecommended,
    required this.bestPlantingPeriod,
    required this.expectedHarvestPeriod,
    this.score = 0,
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
}
