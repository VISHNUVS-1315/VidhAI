import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/models/ai/ai_message.dart';
import 'package:vidhai/services/ai/ai_chat_brain.dart';
import 'package:vidhai/services/crop_validation_engine.dart';

/// Structured AI recommendation response
class AICropRecommendation {
  final String crop;
  final int suitabilityScore;
  final String suitabilityLevel;
  final String reason;
  final String soilCompatibility;
  final String waterRequirement;
  final String waterCompatibility;
  final String seasonCompatibility;
  final String durationDays;
  final String plantingWindow;
  final InvestmentEstimate investment;
  final RevenueEstimate revenue;
  final ProfitEstimate profit;
  final List<String> risks;
  final String explanation;

  const AICropRecommendation({
    required this.crop,
    required this.suitabilityScore,
    required this.suitabilityLevel,
    required this.reason,
    required this.soilCompatibility,
    required this.waterRequirement,
    required this.waterCompatibility,
    required this.seasonCompatibility,
    required this.durationDays,
    required this.plantingWindow,
    required this.investment,
    required this.revenue,
    required this.profit,
    required this.risks,
    required this.explanation,
  });

  factory AICropRecommendation.fromJson(Map<String, dynamic> json) {
    return AICropRecommendation(
      crop: json['crop'] ?? '',
      suitabilityScore: (json['suitabilityScore'] as num?)?.toInt() ?? 0,
      suitabilityLevel: json['suitabilityLevel'] ?? '',
      reason: json['reason'] ?? '',
      soilCompatibility: json['soilCompatibility'] ?? '',
      waterRequirement: json['waterRequirement'] ?? '',
      waterCompatibility: json['waterCompatibility'] ?? '',
      seasonCompatibility: json['seasonCompatibility'] ?? '',
      durationDays: json['durationDays'] ?? '',
      plantingWindow: json['plantingWindow'] ?? '',
      investment: InvestmentEstimate.fromJson(json['investment'] ?? {}),
      revenue: RevenueEstimate.fromJson(json['revenue'] ?? {}),
      profit: ProfitEstimate.fromJson(json['profit'] ?? {}),
      risks: (json['risks'] as List?)?.map((e) => e.toString()).toList() ?? [],
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'crop': crop,
        'suitabilityScore': suitabilityScore,
        'suitabilityLevel': suitabilityLevel,
        'reason': reason,
        'soilCompatibility': soilCompatibility,
        'waterRequirement': waterRequirement,
        'waterCompatibility': waterCompatibility,
        'seasonCompatibility': seasonCompatibility,
        'durationDays': durationDays,
        'plantingWindow': plantingWindow,
        'investment': investment.toJson(),
        'revenue': revenue.toJson(),
        'profit': profit.toJson(),
        'risks': risks,
        'explanation': explanation,
      };
}

class InvestmentEstimate {
  final int min;
  final int max;

  const InvestmentEstimate({required this.min, required this.max});

  factory InvestmentEstimate.fromJson(Map<String, dynamic> json) {
    return InvestmentEstimate(
      min: (json['min'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};
}

class RevenueEstimate {
  final int min;
  final int max;

  const RevenueEstimate({required this.min, required this.max});

  factory RevenueEstimate.fromJson(Map<String, dynamic> json) {
    return RevenueEstimate(
      min: (json['min'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};
}

class ProfitEstimate {
  final int min;
  final int max;

  const ProfitEstimate({required this.min, required this.max});

  factory ProfitEstimate.fromJson(Map<String, dynamic> json) {
    return ProfitEstimate(
      min: (json['min'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};
}

class AIRejectedCrop {
  final String crop;
  final String reason;

  const AIRejectedCrop({required this.crop, required this.reason});

  factory AIRejectedCrop.fromJson(Map<String, dynamic> json) {
    return AIRejectedCrop(
      crop: json['crop'] ?? '',
      reason: json['reason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'crop': crop, 'reason': reason};
}

class AIRankingResult {
  final List<AICropRecommendation> recommendations;
  final List<AIRejectedCrop> rejectedCrops;

  const AIRankingResult({
    required this.recommendations,
    required this.rejectedCrops,
  });

  factory AIRankingResult.fromJson(Map<String, dynamic> json) {
    return AIRankingResult(
      recommendations: (json['recommendations'] as List?)
              ?.map((e) => AICropRecommendation.fromJson(e))
              .toList() ??
          [],
      rejectedCrops: (json['rejectedCrops'] as List?)
              ?.map((e) => AIRejectedCrop.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// AI-powered crop ranker that analyzes validated candidates deeply
class CropAIRanker {
  CropAIRanker._();
  static final CropAIRanker _instance = CropAIRanker._();
  static CropAIRanker get instance => _instance;

  static const Duration _timeout = Duration(seconds: 30);

  /// Ranks validated crops using AI with structured prompt
  Future<AIRankingResult?> rankCrops({
    required FarmValidationContext context,
    required List<ValidatedCrop> candidates,
    required String language,
  }) async {
    if (candidates.isEmpty) return null;

    final prompt = _buildPrompt(context, candidates, language);

    try {
      final reply = await AiChatBrain.chat(
        messages: [AIMessage.user(prompt)],
        language: language,
        timeout: _timeout,
      );

      if (!reply.success || reply.content.trim().isEmpty) {
        return null;
      }

      return _parseResponse(reply.content, candidates);
    } catch (e) {
      debugPrint('[CropAIRanker] AI ranking failed: $e');
      return null;
    }
  }

  String _buildPrompt(
    FarmValidationContext context,
    List<ValidatedCrop> candidates,
    String language,
  ) {
    final farm = context.farm;
    final q = context.questionnaire;
    final budget = context.budgetPerAcre;
    final area = context.farmAreaAcres;

    final candidateList = candidates
        .map((c) => '''
- ${c.crop.name} (${c.crop.variety})
  Category: ${c.crop.category}
  Duration: ${c.crop.durationDays} days (${c.crop.durationCategory})
  Water Need: ${c.crop.waterRequirement}
  Suitable Soils: ${c.crop.suitableSoils.join(', ')}
  Suitable States: ${c.crop.suitableStates.take(8).join(', ')}
  Season: ${c.crop.season}
  Investment/acre: ${c.crop.investmentPerAcre}
  Revenue/acre: ${c.crop.revenuePerAcre}
  Profit/acre: ${c.crop.profitPerAcre}
  Market Demand: ${c.crop.marketDemand}
  Risk Level: ${c.crop.riskLevel}
  Best Planting: ${c.crop.bestPlantingMonth}
  Harvest: ${c.crop.harvestMonth}
  Validation Score: ${c.suitabilityScores.total.toStringAsFixed(1)}/100
  Score Breakdown: Soil=${(c.suitabilityScores.soil * 20).round()}, Water=${(c.suitabilityScores.water * 20).round()}, Climate=${(c.suitabilityScores.climate * 15).round()}, Season=${(c.suitabilityScores.season * 15).round()}, Duration=${(c.suitabilityScores.duration * 10).round()}, Rotation=${(c.suitabilityScores.rotation * 8).round()}, Budget=${(c.suitabilityScores.budget * 7).round()}, Irrigation=${(c.suitabilityScores.irrigation * 5).round()}
  Warnings: ${c.constraintResult.warnings.join('; ')}''')
        .join('\n');

    final previousCrops = context.previousCrops.isNotEmpty
        ? context.previousCrops.join(', ')
        : 'None recorded';

    final weatherInfo = context.currentTemperature != null
        ? 'Current: ${context.currentTemperature}°C, Rainfall: ${context.currentRainfall ?? 0}mm'
        : 'Not available';

    return '''
Analyze these VALIDATED candidate crops for the specific farm below. 

FARM PROFILE:
- Location: ${farm.farmLocation?.district ?? ''}, ${farm.farmLocation?.state ?? ''}
- Farm Size: ${area.toStringAsFixed(1)} acres
- Soil Type: ${farm.soilType.isNotEmpty ? farm.soilType : 'Not specified'}
- Water Availability: ${farm.waterAvailability.isNotEmpty ? farm.waterAvailability : 'Not specified'}
- Water Source: ${farm.waterSource.isNotEmpty ? farm.waterSource : 'Not specified'}
- Irrigation Method: ${farm.irrigationType.isNotEmpty ? farm.irrigationType : 'Not specified'}
- Current Season: ${context.currentSeason}
- Current Month: ${context.currentMonth}
- $weatherInfo

FARMER PREFERENCES:
- Crop Category: ${q.cropCategoryPreference.isNotEmpty ? q.cropCategoryPreference : 'No preference'}
- Crop Duration: ${q.cropDurationPreference.isNotEmpty ? q.cropDurationPreference : 'No preference'}
- Budget per Acre: ${budget > 0 ? '₹$budget' : 'Not specified'}
- Total Farm Budget: ${budget > 0 ? '₹${(budget * area).round()}' : 'Not specified'}

FARM HISTORY:
- Previous Crops: $previousCrops
- Land Fallow: ${q.landIdleDuration.isNotEmpty ? q.landIdleDuration : 'Not specified'}
- Last Harvest: ${q.harvestDate.isNotEmpty ? q.harvestDate : 'Not specified'}

VALIDATED CANDIDATE CROPS (already passed hard constraints):
$candidateList

INSTRUCTIONS:
1. Analyze ONLY these validated crops against the complete farm profile above
2. Do NOT recommend a crop solely because it is commonly grown in India
3. Penalize or reject crops that conflict with soil, water, season, duration, crop rotation, location, or farmer budget
4. Rank crops by agronomic suitability FIRST, economic potential SECOND
5. For each crop, provide detailed reasoning linking back to specific farm inputs
6. If evidence is insufficient for a crop, explicitly state uncertainty rather than inventing information
7. Return ONLY valid JSON matching the exact structure below

REQUIRED JSON STRUCTURE:
{
  "recommendations": [
    {
      "crop": "Crop Name",
      "suitabilityScore": 0-100,
      "suitabilityLevel": "Highly Suitable|Suitable|Moderate / Conditional|Low Suitability",
      "reason": "Specific reason tied to farm inputs (soil, water, season, rotation, budget, duration)",
      "soilCompatibility": "Good match / Moderate / Poor - with brief reason",
      "waterRequirement": "Low / Moderate / High / Very High",
      "waterCompatibility": "Matches farm water availability / Conditional / Insufficient - with reason",
      "seasonCompatibility": "Ideal now / Sow soon / Next window / Not now - with reason",
      "durationDays": "X-Y days",
      "plantingWindow": "Specific months for this location",
      "investment": {"min": 0, "max": 0},
      "revenue": {"min": 0, "max": 0},
      "profit": {"min": 0, "max": 0},
      "risks": ["risk1", "risk2"],
      "explanation": "Detailed explanation of how farmer inputs affected this recommendation. Reference specific values: soil type, water level, season, previous crop, budget, duration preference."
    }
  ],
  "rejectedCrops": [
    {
      "crop": "Crop Name",
      "reason": "Specific hard constraint violation or major concern"
    }
  ]
}

IMPORTANT:
- Investment, revenue, profit must be for the TOTAL farm area (${area.toStringAsFixed(1)} acres), not per-acre
- Use the validated score as a baseline but adjust based on deeper analysis
- Suitability levels: 85-100=Highly Suitable, 70-84=Suitable, 55-69=Moderate/Conditional, <55=Low
- Include 2-3 specific risks per crop
- Rejected crops should explain WHY they failed hard constraints
''';
  }

  AIRankingResult? _parseResponse(
    String content,
    List<ValidatedCrop> candidates,
  ) {
    try {
      // Extract JSON from response (handle markdown code blocks)
      String jsonStr = content.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      }
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return AIRankingResult.fromJson(decoded);
      }
      return null;
    } catch (e) {
      debugPrint('[CropAIRanker] JSON parse failed: $e');
      return null;
    }
  }
}

/// Extended FarmValidationContext for AI ranker
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