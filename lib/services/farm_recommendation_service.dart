import 'dart:math';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/crop_knowledge_base.dart';

class FarmRecommendationService {
  static final FarmRecommendationService _instance = FarmRecommendationService._();
  factory FarmRecommendationService() => _instance;
  FarmRecommendationService._();

  final CropKnowledgeBase _knowledgeBase = CropKnowledgeBase();

  List<CropRecommendation> getRecommendations({
    required FarmProfile farm,
    CropSetupQuestionnaire? questionnaire,
    String? currentSeason,
    String? currentMonth,
  }) {
    final state = farm.farmLocation?.state ?? '';
    final district = farm.farmLocation?.district ?? '';
    final soilType = farm.soilType;
    final waterAvailability = farm.waterAvailability;

    final season = currentSeason ?? _getCurrentSeason();
    final durationPref = questionnaire?.cropDurationPreference ?? '';
    final categoryPref = questionnaire?.cropCategoryPreference ?? '';

    // Step 1: Filter by location/season/soil/water
    var candidates = _knowledgeBase.filter(
      state: state, district: district, soilType: soilType,
      waterAvailability: waterAvailability, season: season,
    );

    // Step 2: Filter by duration preference
    if (durationPref.isNotEmpty && durationPref.toLowerCase() != 'no preference') {
      final durLower = durationPref.toLowerCase();
      candidates = candidates.where((c) {
        if (durLower.contains('short')) return c.durationCategory == 'short';
        if (durLower.contains('medium')) return c.durationCategory == 'medium';
        if (durLower.contains('long')) return c.durationCategory == 'long';
        return true;
      }).toList();
    }

    // Step 3: Filter by category preference
    if (categoryPref.isNotEmpty && categoryPref.toLowerCase() != 'other') {
      candidates = candidates.where((c) => c.category.toLowerCase() == categoryPref.toLowerCase()).toList();
    }

    // Step 4: If no candidates match, fall back to all crops for the state
    if (candidates.isEmpty) {
      candidates = _knowledgeBase.filter(state: state, waterAvailability: waterAvailability);
    }
    if (candidates.isEmpty) {
      candidates = _knowledgeBase.filter(waterAvailability: waterAvailability);
    }
    if (candidates.isEmpty) {
      candidates = List.from(_knowledgeBase.allCrops);
    }

    // Step 5: Score and rank candidates
    final scored = candidates.map((crop) {
      double score = 50.0;

      // Soil match bonus
      if (crop.suitableSoils.map((s) => s.toLowerCase()).contains(soilType.toLowerCase()) || crop.suitableSoils.contains('All')) {
        score += 10;
      }

      // Water match bonus
      final water = waterAvailability.toLowerCase();
      final req = crop.waterRequirement.toLowerCase();
      if (water == 'high' && (req == 'high' || req == 'medium')) score += 10;
      if (water == 'medium' && (req == 'medium' || req == 'low')) score += 10;
      if (water == 'low' && req == 'low') score += 10;
      if (water == 'very low' && (req == 'low' || req == 'very low')) score += 10;

      // Market demand bonus
      if (crop.marketDemand.toLowerCase() == 'high') score += 8;
      if (crop.marketDemand.toLowerCase() == 'medium') score += 4;

      // Risk penalty
      if (crop.riskLevel.toLowerCase() == 'low') score += 5;
      if (crop.riskLevel.toLowerCase() == 'high') score -= 5;

      // Previous crop bonus (avoid same crop)
      if (questionnaire != null) {
        final lastCrop = questionnaire.lastCrop.toLowerCase();
        if (lastCrop.isNotEmpty && crop.name.toLowerCase() != lastCrop) score += 5;
        // Legumes bonus if last crop was non-legume (nitrogen fixing)
        if (crop.category == 'Pulses') score += 3;
      }

      // Random noise for variety
      score += Random().nextDouble() * 5;

      return MapEntry(crop, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    // Return top 10
    final top = scored.take(10).toList();

    return top.map((entry) {
      final crop = entry.key;
      return CropRecommendation(
        cropId: crop.id,
        cropName: crop.name,
        variety: crop.variety,
        category: crop.category,
        duration: '${crop.durationDays} days',
        suitableSoil: crop.suitableSoils.join(', '),
        waterRequirement: crop.waterRequirement,
        suitableClimate: crop.suitableTemperature,
        expectedYield: crop.expectedYieldPerAcre,
        estimatedInvestment: crop.investmentPerAcre,
        expectedRevenue: crop.revenuePerAcre,
        potentialProfit: crop.profitPerAcre,
        marketAvailability: crop.marketDemand,
        riskLevel: crop.riskLevel,
        whyRecommended: _generateReasoning(crop, farm, questionnaire, season),
        bestPlantingPeriod: crop.bestPlantingMonth,
        expectedHarvestPeriod: crop.harvestMonth,
        score: entry.value,
      );
    }).toList();
  }

  String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 6 && month <= 9) return 'Kharif';
    if (month >= 10 && month <= 3) return 'Rabi';
    return 'Zaid';
  }

  String _generateReasoning(CropKnowledgeEntry crop, FarmProfile farm, CropSetupQuestionnaire? q, String season) {
    final reasons = <String>[];
    reasons.add('Suitable for ${farm.farmLocation?.state ?? "your region"} climate');
    if (crop.suitableSoils.map((s) => s.toLowerCase()).contains(farm.soilType.toLowerCase()) || crop.suitableSoils.contains('All')) {
      reasons.add('Matches your ${farm.soilType} soil type');
    }
    if (crop.waterRequirement.toLowerCase() == 'low' && (farm.waterAvailability.toLowerCase() == 'low' || farm.waterAvailability.toLowerCase() == 'very low')) {
      reasons.add('Low water requirement suits your water availability');
    }
    if (crop.marketDemand.toLowerCase() == 'high') reasons.add('High market demand');
    if (crop.riskLevel.toLowerCase() == 'low') reasons.add('Low risk crop');
    if (season.toLowerCase() == crop.season.toLowerCase() || crop.season.toLowerCase() == 'all') {
      reasons.add('Suitable for current $season season');
    }
    return reasons.join('. ');
  }
}
