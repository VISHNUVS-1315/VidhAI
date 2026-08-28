import 'package:vidhai/data/models/user_profile.dart';

class SoilAiResult {
  final String soilType;
  final String characteristics;
  final double confidence;
  final String suitability;
  final String observations;
  final String? imagePath;
  final DateTime? analyzedAt;

  const SoilAiResult({
    required this.soilType,
    required this.characteristics,
    required this.confidence,
    required this.suitability,
    required this.observations,
    this.imagePath,
    this.analyzedAt,
  });

  Map<String, dynamic> toMap() => {
    'soilType': soilType, 'characteristics': characteristics,
    'confidence': confidence, 'suitability': suitability,
    'observations': observations, 'imagePath': imagePath,
    'analyzedAt': analyzedAt?.toIso8601String(),
  };

  factory SoilAiResult.fromMap(Map<String, dynamic> m) => SoilAiResult(
    soilType: m['soilType'] ?? '', characteristics: m['characteristics'] ?? '',
    confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
    suitability: m['suitability'] ?? '', observations: m['observations'] ?? '',
    imagePath: m['imagePath'],
    analyzedAt: m['analyzedAt'] != null ? DateTime.tryParse(m['analyzedAt']) : null,
  );
}

class FarmProfile {
  final String farmId;
  final int index;
  final String farmName;
  final String farmSize;
  final String farmSizeUnit;
  final AddressData? farmLocation;
  final String irrigationType;
  final String waterSource;
  final String soilType;
  final String waterAvailability;
  final String farmingMethod;
  final SoilAiResult? soilAiResult;
  final bool isActive;
  final DateTime? createdAt;

  const FarmProfile({
    required this.farmId,
    required this.index,
    this.farmName = '',
    this.farmSize = '',
    this.farmSizeUnit = 'Acre',
    this.farmLocation,
    this.irrigationType = '',
    this.waterSource = '',
    this.soilType = '',
    this.waterAvailability = '',
    this.farmingMethod = '',
    this.soilAiResult,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'farmId': farmId, 'index': index,
    'farmName': farmName, 'farmSize': farmSize, 'farmSizeUnit': farmSizeUnit,
    'farmLocation': farmLocation?.toMap(),
    'irrigationType': irrigationType, 'waterSource': waterSource,
    'soilType': soilType, 'waterAvailability': waterAvailability,
    'farmingMethod': farmingMethod, 'soilAiResult': soilAiResult?.toMap(),
    'isActive': isActive, 'createdAt': createdAt?.toIso8601String(),
  };

  factory FarmProfile.fromMap(Map<String, dynamic> m) => FarmProfile(
    farmId: m['farmId'] ?? '',
    index: m['index'] ?? 0,
    farmName: m['farmName'] ?? '', farmSize: m['farmSize'] ?? '',
    farmSizeUnit: m['farmSizeUnit'] ?? 'Acre',
    farmLocation: m['farmLocation'] != null
        ? AddressData.fromMap(Map<String, dynamic>.from(m['farmLocation']))
        : null,
    irrigationType: m['irrigationType'] ?? '', waterSource: m['waterSource'] ?? '',
    soilType: m['soilType'] ?? '', waterAvailability: m['waterAvailability'] ?? '',
    farmingMethod: m['farmingMethod'] ?? '',
    soilAiResult: m['soilAiResult'] != null
        ? SoilAiResult.fromMap(Map<String, dynamic>.from(m['soilAiResult']))
        : null,
    isActive: m['isActive'] ?? true,
    createdAt: m['createdAt'] != null ? DateTime.tryParse(m['createdAt']) ?? DateTime.now() : DateTime.now(),
  );

  FarmProfile copyWith({
    String? farmName, String? farmSize, String? farmSizeUnit,
    AddressData? farmLocation, String? irrigationType, String? waterSource,
    String? soilType, String? waterAvailability, String? farmingMethod,
    SoilAiResult? soilAiResult, bool? isActive,
  }) => FarmProfile(
    farmId: farmId, index: index,
    farmName: farmName ?? this.farmName,
    farmSize: farmSize ?? this.farmSize,
    farmSizeUnit: farmSizeUnit ?? this.farmSizeUnit,
    farmLocation: farmLocation ?? this.farmLocation,
    irrigationType: irrigationType ?? this.irrigationType,
    waterSource: waterSource ?? this.waterSource,
    soilType: soilType ?? this.soilType,
    waterAvailability: waterAvailability ?? this.waterAvailability,
    farmingMethod: farmingMethod ?? this.farmingMethod,
    soilAiResult: soilAiResult ?? this.soilAiResult,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt,
  );

  bool get isComplete =>
      farmName.isNotEmpty && farmSize.isNotEmpty &&
      farmLocation != null && irrigationType.isNotEmpty &&
      waterSource.isNotEmpty && soilType.isNotEmpty &&
      waterAvailability.isNotEmpty;
}
