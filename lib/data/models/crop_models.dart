class CropRecord {
  final String id;
  final String farmId;
  final String cropName;
  final String variety;
  final String category;
  final String duration;
  final DateTime plantingDate;
  final DateTime? expectedHarvestDate;
  final String status; // active, harvested, failed
  final String? notes;

  CropRecord({
    required this.id, required this.farmId, required this.cropName,
    required this.variety, required this.category, required this.duration,
    required this.plantingDate, this.expectedHarvestDate,
    this.status = 'active', this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'farmId': farmId, 'cropName': cropName, 'variety': variety,
    'category': category, 'duration': duration,
    'plantingDate': plantingDate.toIso8601String(),
    'expectedHarvestDate': expectedHarvestDate?.toIso8601String(),
    'status': status, 'notes': notes,
  };

  factory CropRecord.fromMap(Map<String, dynamic> m) => CropRecord(
    id: m['id'] ?? '', farmId: m['farmId'] ?? '', cropName: m['cropName'] ?? '',
    variety: m['variety'] ?? '', category: m['category'] ?? '',
    duration: m['duration'] ?? '',
    plantingDate: m['plantingDate'] != null ? DateTime.parse(m['plantingDate']) : DateTime.now(),
    expectedHarvestDate: m['expectedHarvestDate'] != null ? DateTime.parse(m['expectedHarvestDate']) : null,
    status: m['status'] ?? 'active', notes: m['notes'],
  );

  CropRecord copyWith({String? cropName, String? variety, String? status, DateTime? expectedHarvestDate}) =>
      CropRecord(id: id, farmId: farmId, cropName: cropName ?? this.cropName,
          variety: variety ?? this.variety, category: category, duration: duration,
          plantingDate: plantingDate, expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
          status: status ?? this.status, notes: notes);
}

class CropSetupQuestionnaire {
  final String lastCrop;
  final String harvestDate;
  final String landIdleDuration;
  final String lastIrrigation;
  final String waterAvailability;
  final String soilType;
  final String soilCondition;
  final String irrigationSystem;
  final String farmLocation;
  final String farmSize;
  final String currentSeason;
  final String cropDurationPreference;
  final String cropCategoryPreference;

  CropSetupQuestionnaire({
    this.lastCrop = '', this.harvestDate = '', this.landIdleDuration = '',
    this.lastIrrigation = '', this.waterAvailability = '', this.soilType = '',
    this.soilCondition = '', this.irrigationSystem = '', this.farmLocation = '',
    this.farmSize = '', this.currentSeason = '', this.cropDurationPreference = '',
    this.cropCategoryPreference = '',
  });

  Map<String, dynamic> toMap() => {
    'lastCrop': lastCrop, 'harvestDate': harvestDate,
    'landIdleDuration': landIdleDuration, 'lastIrrigation': lastIrrigation,
    'waterAvailability': waterAvailability, 'soilType': soilType,
    'soilCondition': soilCondition, 'irrigationSystem': irrigationSystem,
    'farmLocation': farmLocation, 'farmSize': farmSize,
    'currentSeason': currentSeason, 'cropDurationPreference': cropDurationPreference,
    'cropCategoryPreference': cropCategoryPreference,
  };

  factory CropSetupQuestionnaire.fromMap(Map<String, dynamic> m) =>
      CropSetupQuestionnaire(
        lastCrop: m['lastCrop'] ?? '', harvestDate: m['harvestDate'] ?? '',
        landIdleDuration: m['landIdleDuration'] ?? '',
        lastIrrigation: m['lastIrrigation'] ?? '',
        waterAvailability: m['waterAvailability'] ?? '',
        soilType: m['soilType'] ?? '', soilCondition: m['soilCondition'] ?? '',
        irrigationSystem: m['irrigationSystem'] ?? '',
        farmLocation: m['farmLocation'] ?? '', farmSize: m['farmSize'] ?? '',
        currentSeason: m['currentSeason'] ?? '',
        cropDurationPreference: m['cropDurationPreference'] ?? '',
        cropCategoryPreference: m['cropCategoryPreference'] ?? '',
      );
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

  CropRecommendation({
    required this.cropId, required this.cropName, required this.variety,
    required this.category, required this.duration, required this.suitableSoil,
    required this.waterRequirement, required this.suitableClimate,
    required this.expectedYield, required this.estimatedInvestment,
    required this.expectedRevenue, required this.potentialProfit,
    required this.marketAvailability, required this.riskLevel,
    required this.whyRecommended, required this.bestPlantingPeriod,
    required this.expectedHarvestPeriod, this.score = 0,
  });
}
