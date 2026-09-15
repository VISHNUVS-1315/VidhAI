import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/crop_agronomy_data.dart';
import 'package:vidhai/services/crop_analytics.dart';
import 'package:vidhai/services/crop_knowledge_base.dart';

/// Hard constraint result for a crop
class CropConstraintResult {
  final bool passes;
  final List<String> violations;
  final List<String> warnings;

  const CropConstraintResult({
    required this.passes,
    required this.violations,
    required this.warnings,
  });

  factory CropConstraintResult.pass({List<String> warnings = const []}) {
    return CropConstraintResult(
      passes: true,
      violations: const [],
      warnings: warnings,
    );
  }

  factory CropConstraintResult.fail(
      {required List<String> violations, List<String> warnings = const []}) {
    return CropConstraintResult(
      passes: false,
      violations: violations,
      warnings: warnings,
    );
  }
}

/// Suitability scoring components
class SuitabilityScores {
  final double soil;
  final double water;
  final double climate;
  final double season;
  final double duration;
  final double rotation;
  final double budget;
  final double irrigation;

  const SuitabilityScores({
    required this.soil,
    required this.water,
    required this.climate,
    required this.season,
    required this.duration,
    required this.rotation,
    required this.budget,
    required this.irrigation,
  });

  double get total {
    return (soil * 20) +
        (water * 20) +
        (climate * 15) +
        (season * 15) +
        (duration * 10) +
        (rotation * 8) +
        (budget * 7) +
        (irrigation * 5);
  }

  Map<String, double> toComponents() => {
        'soil': soil,
        'water': water,
        'climate': climate,
        'season': season,
        'duration': duration,
        'rotation': rotation,
        'budget': budget,
        'irrigation': irrigation,
      };

  String get level {
    final score = total;
    if (score >= 85) return 'Highly Suitable';
    if (score >= 70) return 'Suitable';
    if (score >= 55) return 'Moderate / Conditional';
    return 'Low Suitability';
  }
}

/// Complete farm context for validation
class FarmValidationContext {
  final FarmProfile farm;
  final CropSetupQuestionnaire questionnaire;
  final List<String> previousCrops;
  final Map<String, dynamic>? weather;
  final int currentMonth;
  final String currentSeason;
  final double farmAreaAcres;
  final int budgetPerAcre;
  final double? currentTemperature;
  final double? currentRainfall;

  const FarmValidationContext({
    required this.farm,
    required this.questionnaire,
    required this.previousCrops,
    this.weather,
    required this.currentMonth,
    required this.currentSeason,
    required this.farmAreaAcres,
    required this.budgetPerAcre,
    this.currentTemperature,
    this.currentRainfall,
  });
}

/// Agricultural validation engine with hard constraints and suitability scoring
class CropValidationEngine {
  CropValidationEngine._();
  static final CropValidationEngine _instance = CropValidationEngine._();
  static CropValidationEngine get instance => _instance;

  final CropKnowledgeBase _knowledgeBase = CropKnowledgeBase();

  /// Validates a crop against hard constraints
  CropConstraintResult validateHardConstraints(
    CropKnowledgeEntry crop,
    FarmValidationContext context,
  ) {
    final violations = <String>[];
    final warnings = <String>[];

    // 1. Soil incompatibility - HARD
    if (context.farm.soilType.isNotEmpty) {
      final soils = crop.suitableSoils.map((s) => s.toLowerCase()).toList();
      if (!soils.contains(context.farm.soilType.toLowerCase()) &&
          !soils.contains('all')) {
        violations.add(
            'Soil type "${context.farm.soilType}" is incompatible with ${crop.name}. '
            'Requires: ${crop.suitableSoils.join(", ")}');
      }
    }

    // 2. Severe water incompatibility - HARD
    if (context.farm.waterAvailability.isNotEmpty) {
      final water = context.farm.waterAvailability.toLowerCase();
      final req = crop.waterRequirement.toLowerCase();

      if (water == 'no water' && req != 'low') {
        violations.add(
            '${crop.name} requires ${reqLabel(req)} water but your farm has no irrigation (rainfed only).');
      } else if (water == 'very low' &&
          (req == 'high' || req == 'very high')) {
        violations.add(
            '${crop.name} requires ${reqLabel(req)} water but your farm has very low water availability.');
      } else if (water == 'low' && req == 'very high') {
        violations.add(
            '${crop.name} requires very high water but your farm has low water availability.');
      } else if (water == 'low' && req == 'high') {
        warnings.add(
            '${crop.name} requires high water but your farm has low availability. Consider drip irrigation.');
      }
    }

    // 3. Duration incompatibility - HARD
    final durationPref = context.questionnaire.cropDurationPreference;
    if (durationPref.isNotEmpty &&
        durationPref.toLowerCase() != 'no preference') {
      final bands = _durationBands(durationPref);
      if (!bands.contains(crop.durationCategory)) {
        violations.add(
            '${crop.name} (${crop.durationCategory} duration: ${crop.durationDays} days) '
            'does not match your preferred duration: $durationPref.');
      }
    }

    // 4. Season incompatibility - HARD
    if (context.currentSeason.isNotEmpty) {
      final cropSeason = crop.season.toLowerCase();
      if (cropSeason != 'all' && cropSeason != context.currentSeason.toLowerCase()) {
        violations.add(
            '${crop.name} is a ${crop.season} crop but current season is ${context.currentSeason}. '
            'Planting now is not recommended.');
      }
    }

    // 5. Budget incompatibility - HARD (if significantly exceeds)
    if (context.budgetPerAcre > 0) {
      final costRange = CropAnalytics.parseRange(crop.investmentPerAcre);
      if (costRange.isKnown && costRange.avg > context.budgetPerAcre * 2) {
        violations.add(
            '${crop.name} estimated investment (${crop.investmentPerAcre}/acre) '
            'significantly exceeds your budget (₹${context.budgetPerAcre}/acre).');
      } else if (costRange.isKnown && costRange.avg > context.budgetPerAcre * 1.5) {
        warnings.add(
            '${crop.name} investment (${crop.investmentPerAcre}/acre) exceeds your budget. '
            'Consider if you can arrange additional funds.');
      }
    }

    // 6. Regional/climatic incompatibility - HARD
    if (context.farm.farmLocation?.state?.isNotEmpty == true) {
      final state = context.farm.farmLocation!.state!;
      final states = crop.suitableStates.map((s) => s.toLowerCase()).toList();
      if (!states.contains(state.toLowerCase()) && !states.contains('all india')) {
        // Not a hard violation, but a warning
        warnings.add(
            '${crop.name} is not commonly grown in $state. Verify local suitability.');
      }
    }

    // 7. Temperature check
    if (context.currentTemperature != null) {
      final tempRange = CropAnalytics.parseRange(crop.suitableTemperature);
      if (tempRange.isKnown) {
        final temp = context.currentTemperature!;
        if (temp < tempRange.min - 5 || temp > tempRange.max + 5) {
          warnings.add(
              'Current temperature ($temp°C) is outside ${crop.name}\'s ideal range (${crop.suitableTemperature}).');
        }
      }
    }

    // 8. Irrigation method compatibility
    if (context.farm.irrigationType.isNotEmpty) {
      final irrigation = context.farm.irrigationType.toLowerCase();
      final req = crop.waterRequirement.toLowerCase();
      if (req == 'high' &&
          (irrigation.contains('drip') || irrigation.contains('sprinkler'))) {
        warnings.add(
            '${crop.name} has high water needs. Drip/sprinkler may not provide sufficient water volume. '
            'Consider flood irrigation or ensure adequate water source.');
      }
    }

    if (violations.isNotEmpty) {
      return CropConstraintResult.fail(violations: violations, warnings: warnings);
    }
    return CropConstraintResult.pass(warnings: warnings);
  }

  /// Calculates detailed suitability scores for a crop
  SuitabilityScores calculateSuitabilityScores(
    CropKnowledgeEntry crop,
    FarmValidationContext context,
  ) {
    // Soil score (0-1)
    double soilScore = 0.5;
    if (context.farm.soilType.isNotEmpty) {
      final soils = crop.suitableSoils.map((s) => s.toLowerCase()).toList();
      soilScore =
          soils.contains(context.farm.soilType.toLowerCase()) || soils.contains('all')
              ? 1.0
              : 0.3;
    }

    // Water score (0-1)
    double waterScore = 0.5;
    if (context.farm.waterAvailability.isNotEmpty) {
      final water = context.farm.waterAvailability.toLowerCase();
      final req = crop.waterRequirement.toLowerCase();
      waterScore = _waterScore(water, req);
    }

    // Climate/location score (0-1)
    double climateScore = 0.6;
    if (context.farm.farmLocation?.state?.isNotEmpty == true) {
      final state = context.farm.farmLocation!.state!;
      final states = crop.suitableStates.map((s) => s.toLowerCase()).toList();
      climateScore =
          states.contains(state.toLowerCase()) || states.contains('all india')
              ? 1.0
              : 0.6;
    }

    // Season score (0-1)
    double seasonScore = 0.5;
    if (context.currentSeason.isNotEmpty) {
      final windows = CropAnalytics.parseMonthWindows(crop.bestPlantingMonth);
      final calendar = CropAnalytics.calendarStatus(windows, context.currentMonth);
      seasonScore = _calendarToScore(calendar.status);
    }

    // Duration score (0-1)
    double durationScore = 0.6;
    final durationPref = context.questionnaire.cropDurationPreference;
    if (durationPref.isNotEmpty &&
        durationPref.toLowerCase() != 'no preference') {
      final bands = _durationBands(durationPref);
      if (crop.durationCategory == bands.first) {
        durationScore = 1.0;
      } else if (bands.length > 1 && crop.durationCategory == bands[1]) {
        durationScore = 0.7;
      } else {
        durationScore = 0.5;
      }
    }

    // Rotation score (0-1)
    double rotationScore = 0.65;
    if (context.previousCrops.isNotEmpty) {
      final agronomy = CropAgronomyData.infoFor(crop);
      final rotation = CropAnalytics.rotationAnalysis(
        candidateName: crop.name,
        candidateFamily: agronomy.family,
        candidateLegume: agronomy.family == 'Fabaceae',
        previousCrops: context.previousCrops,
        familyOf: CropAgronomyData.familyOf,
      );
      rotationScore = rotation.score;
    }

    // Budget score (0-1)
    double budgetScore = 0.6;
    if (context.budgetPerAcre > 0) {
      final costRange = CropAnalytics.parseRange(crop.investmentPerAcre);
      if (costRange.isKnown) {
        final cost = costRange.avg;
        if (cost <= context.budgetPerAcre * 0.7) {
          budgetScore = 0.85;
        } else if (cost <= context.budgetPerAcre * 1.3) {
          budgetScore = 1.0;
        } else if (cost <= context.budgetPerAcre * 2) {
          budgetScore = 0.6;
        } else {
          budgetScore = 0.3;
        }
      }
    }

    // Irrigation score (0-1)
    double irrigationScore = 0.7;
    if (context.farm.irrigationType.isNotEmpty &&
        context.farm.waterAvailability.isNotEmpty) {
      final irrigation = context.farm.irrigationType.toLowerCase();
      final water = context.farm.waterAvailability.toLowerCase();
      final req = crop.waterRequirement.toLowerCase();

      // Good matches
      if (req == 'high' &&
          (irrigation.contains('flood') || irrigation.contains('canal'))) {
        irrigationScore = 1.0;
      } else if (req == 'medium' &&
          (irrigation.contains('drip') ||
              irrigation.contains('sprinkler') ||
              irrigation.contains('borewell'))) {
        irrigationScore = 1.0;
      } else if (req == 'low' && water != 'no water') {
        irrigationScore = 1.0;
      } else if (req == 'high' &&
          (irrigation.contains('drip') || irrigation.contains('sprinkler'))) {
        irrigationScore = 0.6;
      }
    }

    return SuitabilityScores(
      soil: soilScore,
      water: waterScore,
      climate: climateScore,
      season: seasonScore,
      duration: durationScore,
      rotation: rotationScore,
      budget: budgetScore,
      irrigation: irrigationScore,
    );
  }

  /// Filters crops through hard constraints, then scores remaining
  List<ValidatedCrop> validateAndScoreAll(
    FarmValidationContext context,
  ) {
    final candidates = _knowledgeBase.allCrops;
    final results = <ValidatedCrop>[];

    for (final crop in candidates) {
      final constraint = validateHardConstraints(crop, context);
      final scores = calculateSuitabilityScores(crop, context);

      results.add(ValidatedCrop(
        crop: crop,
        constraintResult: constraint,
        suitabilityScores: scores,
      ));
    }

    // Sort by total score descending, hard failures at bottom
    results.sort((a, b) {
      if (a.constraintResult.passes != b.constraintResult.passes) {
        return a.constraintResult.passes ? -1 : 1;
      }
      return b.suitabilityScores.total.compareTo(a.suitabilityScores.total);
    });

    return results;
  }

  /// Gets top N passing crops for AI analysis
  List<ValidatedCrop> getTopCandidates(
    FarmValidationContext context, {
    int limit = 15,
  }) {
    final all = validateAndScoreAll(context);
    return all.where((c) => c.constraintResult.passes).take(limit).toList();
  }

  /// Gets rejected crops with reasons
  List<RejectedCrop> getRejectedCrops(
    FarmValidationContext context, {
    int limit = 10,
  }) {
    final all = validateAndScoreAll(context);
    return all
        .where((c) => !c.constraintResult.passes)
        .take(limit)
        .map((c) => RejectedCrop(
              cropName: c.crop.name,
              violations: c.constraintResult.violations,
              warnings: c.constraintResult.warnings,
              score: c.suitabilityScores.total,
            ))
        .toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _waterScore(String water, String req) {
    if (water.isEmpty) return 0.5;
    if (water == 'no water') return req == 'low' ? 0.9 : 0.2;
    if (water == 'very low') return (req == 'low' || req == 'medium') ? 1.0 : 0.25;
    if (water == 'low') {
      return req == 'very high' ? 0.2 : (req == 'high' ? 0.4 : 1.0);
    }
    if (water == 'medium') {
      return (req == 'medium' || req == 'low') ? 1.0 : 0.7;
    }
    if (water == 'high') return (req == 'high' || req == 'medium') ? 1.0 : 0.8;
    return 0.5;
  }

  double _calendarToScore(String status) {
    switch (status) {
      case 'ideal_now':
        return 1.0;
      case 'sow_soon':
        return 0.85;
      case 'next_window':
        return 0.5;
      case 'not_now':
        return 0.35;
      case 'unknown':
      default:
        return 0.5;
    }
  }

  List<String> _durationBands(String pref) {
    final p = pref.toLowerCase();
    if (p.contains('short')) return const ['short', 'medium'];
    if (p.contains('long')) return const ['long', 'medium'];
    return const ['medium', 'short', 'long'];
  }

  String reqLabel(String req) {
    switch (req) {
      case 'very high':
        return 'very high';
      case 'high':
        return 'high';
      case 'medium':
        return 'moderate';
      case 'low':
        return 'low';
      default:
        return req;
    }
  }
}

/// A crop with validation results and suitability scores
class ValidatedCrop {
  final CropKnowledgeEntry crop;
  final CropConstraintResult constraintResult;
  final SuitabilityScores suitabilityScores;

  const ValidatedCrop({
    required this.crop,
    required this.constraintResult,
    required this.suitabilityScores,
  });

  bool get passesConstraints => constraintResult.passes;

  String get suitabilityLevel => suitabilityScores.level;

  int get score => suitabilityScores.total.round();
}

/// A rejected crop with reasons
class RejectedCrop {
  final String cropName;
  final List<String> violations;
  final List<String> warnings;
  final double score;

  const RejectedCrop({
    required this.cropName,
    required this.violations,
    required this.warnings,
    required this.score,
  });

  String get primaryReason => violations.isNotEmpty ? violations.first : 'Does not meet requirements';
}