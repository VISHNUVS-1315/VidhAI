import 'dart:convert';

import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/crop_agronomy_data.dart';
import 'package:vidhai/services/crop_analytics.dart';
import 'package:vidhai/services/crop_knowledge_base.dart';

/// Deterministic, offline farm-level crop recommendation engine.
///
/// HARD filters (never widened): crop category (when chosen) and sowing
/// duration band. Softer pre-filters (region/soil/water/season) may relax only
/// to keep the list usable, exactly like the legacy fallbacks.
///
/// Every candidate is scored across a transparent, weighted component table
/// (total 100) and the result carries the per-component points, the confidence
/// (share of weighted components backed by real farm data), plus calendar,
/// rotation, economics, risk, weather and market analytics for the UI.
class FarmRecommendationService {
  static final FarmRecommendationService _instance =
      FarmRecommendationService._();
  factory FarmRecommendationService() => _instance;
  FarmRecommendationService._();

  final CropKnowledgeBase _knowledgeBase = CropKnowledgeBase();

  /// Transparent score weights; component scores are 0..1 and scaled back to
  /// 100 at the end (missing data shrinks confidence, never the scale).
  static const Map<String, double> _weights = {
    'category': 15,
    'duration': 10,
    'location': 10,
    'calendar': 10,
    'rotation': 10,
    'soil': 10,
    'water': 10,
    'weather': 8,
    'investment': 7,
    'profit': 5,
    'market': 3,
    'risk': 2,
  };

  List<CropRecommendation> getRecommendations({
    required FarmProfile farm,
    CropSetupQuestionnaire? questionnaire,
    String? currentSeason,
    String? currentMonth,
    List<Map<String, dynamic>>? marketContext,
    List<String>? previousCrops,
    Map<String, dynamic>? weather,
    double? farmAreaAcres,
  }) {
    final state = farm.farmLocation?.state ?? '';
    final district = farm.farmLocation?.district ?? '';
    final soilType = farm.soilType;
    final waterAvailability = farm.waterAvailability;
    final month = int.tryParse(currentMonth ?? '') ?? DateTime.now().month;

    final season = currentSeason ?? _getCurrentSeason();
    final durationPref = questionnaire?.cropDurationPreference ?? '';
    final categoryPref = questionnaire?.cropCategoryPreference ?? '';

    // Step 1: location/soil/water/season pre-filter (may relax only at the
    // location level, exactly like the legacy fallback path).
    var candidates = _knowledgeBase.filter(
      state: state,
      district: district,
      soilType: soilType,
      waterAvailability: waterAvailability,
      season: season,
    );
    if (candidates.isEmpty) {
      candidates = _knowledgeBase.filter(
          state: state, waterAvailability: waterAvailability);
    }
    if (candidates.isEmpty) {
      candidates = _knowledgeBase.filter(waterAvailability: waterAvailability);
    }
    if (candidates.isEmpty) {
      candidates = List.from(_knowledgeBase.allCrops);
    }

    // Step 2: HARD category filter (alias-mapped; never widened). A chosen
    // category that has no verified crops yields an honest empty list.
    final prefLower = categoryPref.trim().toLowerCase();
    final noCategory =
        prefLower.isEmpty || prefLower == 'no preference' || prefLower == 'other';
    if (!noCategory) {
      final kbCategory = CropAgronomyData.categoryToKb(categoryPref);
      if (kbCategory == null) return const [];
      candidates = candidates
          .where((c) => c.category.toLowerCase() == kbCategory.toLowerCase())
          .toList();
      if (candidates.isEmpty) return const [];
    }

    // Step 3: HARD duration filter. When the chosen band is empty the nearest
    // band widens (this is the only relaxation, documented in the UI copy).
    if (durationPref.isNotEmpty &&
        durationPref.toLowerCase() != 'no preference') {
      final bands = _durationBands(durationPref);
      var banded = candidates
          .where((c) => c.durationCategory == bands.first)
          .toList();
      if (banded.isEmpty && bands.length > 1) {
        banded = candidates
            .where((c) => c.durationCategory == bands[1])
            .toList();
      }
      if (banded.isEmpty && bands.length > 2) {
        banded = candidates
            .where((c) => c.durationCategory == bands[2])
            .toList();
      }
      candidates = banded;
    }
    if (candidates.isEmpty) return const [];

    // Step 4: score + enrich every candidate.
    final history = _normaliseHistory(previousCrops, questionnaire);
    final scored = candidates.map((crop) {
      final analysis = _analyze(
          crop, farm, questionnaire, marketContext, weather, history, season,
          month, farmAreaAcres);
      return MapEntry(crop, analysis);
    }).toList();

    scored.sort((a, b) => b.value.score.compareTo(a.value.score));
    final top = scored.take(10).toList();

    return top.map((entry) => _toRecommendation(entry.key, entry.value))
        .toList();
  }

  // ── Duration bands ──────────────────────────────────────────────────────────

  static List<String> _durationBands(String pref) {
    final p = pref.toLowerCase();
    if (p.contains('short')) return const ['short', 'medium'];
    if (p.contains('long')) return const ['long', 'medium'];
    return const ['medium', 'short', 'long'];
  }

  static List<String> _normaliseHistory(
      List<String>? previousCrops, CropSetupQuestionnaire? questionnaire) {
    final out = [if (questionnaire?.lastCrop.trim().isNotEmpty == true) questionnaire!.lastCrop.trim()];
    if (previousCrops != null) {
      for (final name in previousCrops) {
        final t = name.trim();
        if (t.isNotEmpty && !out.contains(t)) out.add(t);
      }
    }
    return out;
  }

  // ── Candidate analysis ──────────────────────────────────────────────────────

  double _num(List<num>? values) => values == null || values.isEmpty ? 0 : values.first.toDouble();

  _CandidateAnalysis _analyze(
    CropKnowledgeEntry crop,
    FarmProfile farm,
    CropSetupQuestionnaire? questionnaire,
    List<Map<String, dynamic>>? marketContext,
    Map<String, dynamic>? weather,
    List<String> history,
    String season,
    int month,
    double? farmAreaAcres,
  ) {
    final agronomy = CropAgronomyData.infoFor(crop);
    final windows = CropAnalytics.parseMonthWindows(crop.bestPlantingMonth);
    final calendar = CropAnalytics.calendarStatus(windows, month);

    final costAvg = CropAnalytics.parseRange(crop.investmentPerAcre).avg;
    final revenueAvg = CropAnalytics.parseRange(crop.revenuePerAcre).avg;
    final profitAvg = CropAnalytics.parseRange(crop.profitPerAcre).avg;
    final margin =
        CropAnalytics.profitMargin(profitAvg, revenueAvg);

    final soilType = farm.soilType;
    final waterAvailability = farm.waterAvailability;
    final parsedArea = farmAreaAcres ??
        CropAnalytics.acresFromFarmSize(farm.farmSize, farm.farmSizeUnit);
    int? farmArea;
    if (parsedArea != null && parsedArea > 0) farmArea = parsedArea.round();

    // ── per-component 0..1 scores ──
    final state = farm.farmLocation?.state ?? '';
    final stateMatch = state.isNotEmpty &&
        (crop.suitableStates.any((s) => s.toLowerCase() == state.toLowerCase()) ||
            crop.suitableStates.contains('All India'));

    final soilMatch = soilType.isNotEmpty &&
        (crop.suitableSoils
                .map((s) => s.toLowerCase())
                .contains(soilType.toLowerCase()) ||
            crop.suitableSoils.contains('All'));

    final water = (waterAvailability.isEmpty ? '' : waterAvailability).toLowerCase();
    final req = crop.waterRequirement.toLowerCase();
    final waterScore = _waterScore(water, req);

    // Weather component (from the live/cached weather bundle or neutral).
    final weatherScore = _weatherScore(weather, crop.suitableTemperature, req);
    var dataSources = <String>[];
    var applied = <String>[];
    if (state.isNotEmpty) {
      dataSources.add('Location');
      applied.add('location');
    } else {
      dataSources.add('General database');
    }
    if (soilType.isNotEmpty) {
      dataSources.add('Soil');
      applied.add('soil');
    }
    if (waterAvailability.isNotEmpty) {
      dataSources.add('Water');
      applied.add('water');
    }
    if (windows.isNotEmpty) {
      dataSources.add('Crop calendar');
      applied.add('calendar');
    }
    if (history.isNotEmpty) {
      dataSources.add('Farm history');
      applied.add('rotation');
    }
    if (weather != null && weather.isNotEmpty) {
      dataSources.add('Weather');
      applied.add('weather');
    }
    if (marketContext != null && marketContext.isNotEmpty) {
      dataSources.add('Market price');
      applied.add('market');
    }
    if (kbCategorySelected(questionnaire)) {
      applied.add('category');
    }
    applied.add('duration');
    if (costAvg > 0 || revenueAvg > 0) {
      applied.add('investment');
    }
    if (profitAvg > 0) applied.add('profit');
    applied.add('risk');

    final rotation = CropAnalytics.rotationAnalysis(
      candidateName: crop.name,
      candidateFamily: agronomy.family,
      candidateLegume: agronomy.family == 'Fabaceae',
      previousCrops: history,
      familyOf: CropAgronomyData.familyOf,
    );

    final rotationScore = rotation.score;
    if (rotation.score < 0.5) applied.add('rotation');

    final categoryScore = kbCategorySelected(questionnaire) ? 1.0 : 0.6;
    final durationScore = _durationScore(crop, questionnaire);

    final locationScore = stateMatch
        ? 1.0
        : (state.isEmpty ? 0.5 : 0.6);

    final calendarScore = _calendarToScore(calendar.status);

    final budget = questionnaire?.budgetInrPerAcre;
    final investmentScore = _investmentScore(costAvg, budget);

    final profitScore = profitAvg <= 0
        ? 0.5
        : margin >= 60
            ? 1.0
            : (margin <= 0 ? 0.2 : margin / 60).clamp(0.1, 1.0).toDouble();

    final marketScore = _marketScore(crop, marketContext);

    final riskScore = _riskScore(crop, calendar.status, rotation, weather);

    final components = <String, double>{
      'category': categoryScore,
      'duration': durationScore,
      'location': locationScore,
      'calendar': calendarScore,
      'rotation': rotationScore,
      'soil': _soilScore(soilMatch, soilType),
      'water': waterScore,
      'weather': weatherScore,
      'investment': investmentScore,
      'profit': profitScore,
      'market': marketScore,
      'risk': riskScore,
    };

    var total = 0.0;
    var appliedWeight = 0.0;
    final points = <String, double>{};
    for (final name in _weights.keys) {
      final s = components[name] ?? 0.5;
      final w = _weights[name]!;
      total += w * s;
      final isApplied = applied.contains(name);
      if (isApplied || name == 'location') {
        appliedWeight += w;
        points[name] = double.parse((w * s).toStringAsFixed(2));
      } else {
        points[name] = double.parse((w * s).toStringAsFixed(2));
      }
    }
    final base = appliedWeight > 0 ? total / appliedWeight : total / 100;
    final normalized = (base * 100).clamp(1, 100).toDouble();

    // Deterministic tie-breaker, tiny enough to never warp the score.
    final finalScore =
        (normalized + _stableFraction(crop.id) * 0.5).clamp(1, 100).toDouble();

    final marketLine = _findMarket(crop, marketContext);
    final area = farmArea;

    final costBreakdown = costAvg > 0
        ? agronomy.costSplit
            .map((s) => CropCostLine(
                  label: s.label,
                  amountPerAcre: costAvg * s.sharePct / 100,
                  sharePct: s.sharePct,
                ))
            .toList()
        : null;

    final weatherStatus = (weather == null || weather.isEmpty)
        ? 'absent'
        : (weather['cacheAgeHours'] is num &&
                (weather['cacheAgeHours'] as num) > 12)
            ? 'cached'
            : 'available';

    return _CandidateAnalysis(
      crop: crop,
      season: season,
      calendarStatus: calendar.status,
      sowingWindow: crop.bestPlantingMonth,
      harvestWindowLocal: crop.harvestMonth,
      rotationAnalysis: rotation.detail,
      previousCrop: history.isEmpty ? null : history.first,
      risk: _riskExplanation(crop, calendar.status, rotation),
      riskScore: (riskScore * 10).round().clamp(1, 10),
      costBreakdown: costBreakdown,
      costPerAcre: costAvg > 0 ? costAvg : null,
      revenuePerAcre: revenueAvg > 0 ? revenueAvg : null,
      profitPerAcre: profitAvg > 0 ? profitAvg : null,
      profitMarginPct: profitAvg > 0 && revenueAvg > 0 ? margin : null,
      farmArea: area,
      totalCost: area != null && costAvg > 0 ? costAvg * area : null,
      totalRevenue: area != null && revenueAvg > 0 ? revenueAvg * area : null,
      totalProfit: area != null && profitAvg > 0 ? profitAvg * area : null,
      yieldPerAcreKg: _parseYieldKg(crop.expectedYieldPerAcre),
      weatherAvailability: weatherStatus,
      marketPricePerKg: marketLine?.price,
      marketPriceSource: marketLine?.source,
      marketPriceDate: marketLine?.date,
      scoreComponents: points,
      dataSources: dataSources,
      confidencePct: appliedWeight > 0
          ? (appliedWeight / 100 * 100).clamp(0, 100).toDouble()
          : 0,
      score: finalScore,
      waterNotes: _waterNotes(water, req),
    );
  }

  bool kbCategorySelected(CropSetupQuestionnaire? q) {
    final pref = q?.cropCategoryPreference ?? '';
    if (pref.isEmpty) return false;
    return CropAgronomyData.categoryToKb(pref) != null;
  }

  double _durationScore(CropKnowledgeEntry crop, CropSetupQuestionnaire? q) {
    final pref = q?.cropDurationPreference ?? '';
    if (pref.isEmpty || pref.toLowerCase() == 'no preference') return 0.6;
    final bands = _durationBands(pref);
    final c = crop.durationCategory;
    if (c == bands.first) return 1.0;
    if (bands.length > 1 && c == bands[1]) return 0.7;
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

  double _soilScore(bool match, String soilType) {
    if (soilType.isEmpty) return 0.5;
    return match ? 1.0 : 0.3;
  }

  /// Weather component. Uses the real bundled weather bundle when present
  /// (temperature fit + rain support), otherwise a neutral 0.5.
  double _weatherScore(Map<String, dynamic>? weather,
      String suitableTemperature, String req) {
    if (weather == null || weather.isEmpty) return 0.5;
    var score = 0.5;
    final temps = arrayOrDirect(weather, 'temperature');
    final temp = temps == null || temps.isEmpty ? 0.0 : temps.first.toDouble();
    if (temp > 0) {
      final cropTemp = CropAnalytics.parseRange(suitableTemperature);
      final cropMin = cropTemp.isKnown ? cropTemp.min : 15;
      final cropMax = cropTemp.isKnown ? cropTemp.max : 35;
      if (temp >= cropMin - 3 && temp <= cropMax + 3) {
        score = 0.95;
      } else if (temp >= cropMin - 8 && temp <= cropMax + 8) {
        score = 0.7;
      } else {
        score = 0.4;
      }
    }
    final rains = arrayOrDirect(weather, 'todayRainMm');
    final rain = rains == null || rains.isEmpty ? 0.0 : rains.first.toDouble();
    if (rain > 0 && (req.contains('high') || req.contains('medium'))) {
      score = (score + 0.05).clamp(0, 1.0).toDouble();
    }
    return score.clamp(0.1, 1.0).toDouble();
  }

  double _investmentScore(double costAvg, int? budget) {
    if (budget == null || budget <= 0 || costAvg <= 0) return 0.6;
    if (costAvg <= budget * 0.7) return 0.85;
    if (costAvg <= budget * 1.3) return 1.0;
    if (costAvg <= budget * 2) return 0.6;
    return 0.3;
  }

  double _marketScore(CropKnowledgeEntry crop,
      List<Map<String, dynamic>>? marketContext) {
    if (marketContext != null && marketContext.isNotEmpty) {
      final found = marketContext.any((m) =>
          (m['commodity'] ?? '').toString().toLowerCase() ==
          crop.name.toLowerCase());
      if (found) return 1.0;
      return 0.6;
    }
    final demand = crop.marketDemand.toLowerCase();
    if (demand == 'high') return 0.9;
    if (demand == 'medium') return 0.7;
    return 0.5;
  }

  double _riskScore(CropKnowledgeEntry crop, String calendarStatus,
      RotationAnalysis rotation, Map<String, dynamic>? weather) {
    double s = 0.7;
    final level = crop.riskLevel.toLowerCase();
    if (level == 'low') {
      s = 0.9;
    } else if (level == 'high') {
      s = 0.4;
    }
    if (calendarStatus == 'not_now') s -= 0.2;
    if (rotation.score < 0.5) s -= 0.2;
    if (weather == null || weather.isEmpty) s -= 0.05;
    return s.clamp(0.1, 1.0).toDouble();
  }

  String _riskExplanation(CropKnowledgeEntry crop, String calendarStatus,
      RotationAnalysis rotation) {
    final parts = <String>[];
    if (rotation.score < 0.5) parts.add(rotation.detail);
    if (calendarStatus == 'not_now') {
      parts.add('Outside the ideal sowing window right now.');
    } else if (calendarStatus == 'sow_soon') {
      parts.add('Sowing window is closing — plant soon.');
    }
    if (crop.riskLevel.toLowerCase() == 'medium') {
      parts.add('Cultivation carries medium risk; manage water and pests.');
    } else if (crop.riskLevel.toLowerCase() == 'low') {
      parts.add('Low known risk for this crop.');
    }
    return parts.isEmpty ? 'No notable risk factors detected for this crop.' : parts.join(' ');
  }

  String _waterNotes(String water, String req) {
    if (water.isEmpty) return 'Water availability is not recorded on this farm.';
    final need = cropWaterNeed(water, req);
    return 'Water requirement: ${reqLabel(req)}. Your farm: $need.';
  }

  String cropWaterNeed(String water, String req) {
    final wNeed = req == 'high'
        ? 'needs regular irrigation'
        : req == 'medium'
            ? 'moderate water'
            : 'low water';
    final farmWater = water.isEmpty
        ? 'not recorded'
        : water == 'no water'
            ? 'rainfed only'
            : water == 'very low'
                ? 'very limited'
                : water;
    return '$wNeed; farm water: $farmWater';
  }

  String reqLabel(String req) =>
      req.isEmpty ? 'not stated' : req;

  CropCostLineData? _findMarket(CropKnowledgeEntry crop,
      List<Map<String, dynamic>>? marketContext) {
    if (marketContext == null) return null;
    for (final m in marketContext) {
      if ((m['commodity'] ?? '').toString().toLowerCase() ==
          crop.name.toLowerCase()) {
        final price = _num(arrayOrDirect(m, 'pricePerKg'));
        if (price <= 0) return null;
        return CropCostLineData(
          price: price,
          source: (m['source'] ?? '').toString(),
          date: (m['date'] ?? m['fetchedDate'] ?? '').toString(),
        );
      }
    }
    return null;
  }

  double? _parseYieldKg(String yieldText) {
    final range = CropAnalytics.parseRange(yieldText);
    if (!range.isKnown) return null;
    final unit = yieldText.toLowerCase();
    final perHectare = unit.contains('hectare') || unit.contains('ha');
    final perAcre = unit.contains('acre');
    final factor = perHectare ? 0.404686 : 1.0;
    if (!perAcre && !perHectare) return null;
    return range.avg * factor;
  }

  // ── Output construction ─────────────────────────────────────────────────────

  CropRecommendation _toRecommendation(
      CropKnowledgeEntry crop, _CandidateAnalysis a) {
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
      whyRecommended: _generateReasoning(crop, a),
      bestPlantingPeriod: crop.bestPlantingMonth,
      expectedHarvestPeriod: crop.harvestMonth,
      score: a.score,
      calendarStatus: a.calendarStatus,
      sowingWindow: a.sowingWindow,
      harvestWindowLocal: a.harvestWindowLocal,
      rotationAnalysis: a.rotationAnalysis,
      previousCrop: a.previousCrop,
      riskExplanation: a.risk,
      riskScore: a.riskScore,
      costBreakdown: a.costBreakdown,
      costPerAcre: a.costPerAcre,
      revenuePerAcre: a.revenuePerAcre,
      profitPerAcre: a.profitPerAcre,
      profitMarginPct: a.profitMarginPct,
      farmAreaAcres: a.farmArea?.toDouble(),
      totalCost: a.totalCost,
      totalRevenue: a.totalRevenue,
      totalProfit: a.totalProfit,
      yieldPerAcreKg: a.yieldPerAcreKg,
      weatherAvailability: a.weatherAvailability,
      marketPricePerKg: a.marketPricePerKg,
      marketPriceSource: a.marketPriceSource,
      marketPriceDate: a.marketPriceDate,
      scoreComponents: a.scoreComponents,
      dataSources: a.dataSources,
      confidencePct: a.confidencePct,
    );
  }

  String _generateReasoning(CropKnowledgeEntry crop, _CandidateAnalysis a) {
    final reasons = <String>[];
    final status = a.calendarStatus;
    if (status == 'ideal_now') {
      reasons.add('Ideal to sow right now (sowing window is open).');
    } else if (status == 'sow_soon') {
      reasons.add('Sowing window is currently open or closing soon.');
    } else if (status == 'next_window') {
      reasons.add('Best sowing window is coming within a few months.');
    } else if (status == 'not_now') {
      reasons.add('Outside the ideal sowing window for this time of year.');
    }
    if (a.rotationAnalysis != null && (a.rotationAnalysis!.toLowerCase().contains('rotation') ||
        a.rotationAnalysis!.contains('follows'))) {
      reasons.add(a.rotationAnalysis!);
    }
    if (a.profitMarginPct != null) {
      reasons.add(
          'Estimated profit margin ~${a.profitMarginPct!.round()}% per acre.');
    }
    if (a.costPerAcre != null) {
      reasons.add(
          'Estimated investment ~₹${CropAnalytics.moneyRound(a.costPerAcre!)}/acre.');
    }
    if (crop.riskLevel.toLowerCase() == 'low') {
      reasons.add('Low risk crop for new and ongoing cultivation.');
    }
    if (crop.marketDemand.toLowerCase() == 'high') {
      reasons.add('High market demand.');
    }
    return reasons.join(' ');
  }

  String _getCurrentSeason() {
    final month = DateTime.now().month;
    if (month >= 6 && month <= 9) return 'Kharif';
    if (month >= 10 || month <= 3) return 'Rabi';
    return 'Zaid';
  }

  double _stableFraction(String input) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3).toUnsigned(64);
    }
    return (hash & 0x7FFFFFFFFFFFFFFF) / 0x7FFFFFFFFFFFFFFF;
  }
}

/// Extracts a numeric key that may be stored as bare number or as a List.
List<num>? arrayOrDirect(Map<String, dynamic>? map, String key) {
  if (map == null) return null;
  final v = map[key];
  if (v is num) return [v];
  if (v is List) return v.whereType<num>().toList();
  return null;
}

class CropCostLineData {
  final double price;
  final String source;
  final String date;
  const CropCostLineData(
      {required this.price, required this.source, required this.date});
}

class _CandidateAnalysis {
  final CropKnowledgeEntry crop;
  final String season;
  final String calendarStatus;
  final String sowingWindow;
  final String harvestWindowLocal;
  final String? rotationAnalysis;
  final String? previousCrop;
  final String risk;
  final int riskScore;
  final List<CropCostLine>? costBreakdown;
  final double? costPerAcre;
  final double? revenuePerAcre;
  final double? profitPerAcre;
  final double? profitMarginPct;
  final int? farmArea;
  final double? totalCost;
  final double? totalRevenue;
  final double? totalProfit;
  final double? yieldPerAcreKg;
  final String weatherAvailability;
  final double? marketPricePerKg;
  final String? marketPriceSource;
  final String? marketPriceDate;
  final Map<String, double> scoreComponents;
  final List<String> dataSources;
  final double confidencePct;
  final double score;
  final String waterNotes;

  const _CandidateAnalysis({
    required this.crop,
    required this.season,
    required this.calendarStatus,
    required this.sowingWindow,
    required this.harvestWindowLocal,
    required this.rotationAnalysis,
    required this.previousCrop,
    required this.risk,
    required this.riskScore,
    required this.costBreakdown,
    required this.costPerAcre,
    required this.revenuePerAcre,
    required this.profitPerAcre,
    required this.profitMarginPct,
    required this.farmArea,
    required this.totalCost,
    required this.totalRevenue,
    required this.totalProfit,
    required this.yieldPerAcreKg,
    required this.weatherAvailability,
    required this.marketPricePerKg,
    required this.marketPriceSource,
    required this.marketPriceDate,
    required this.scoreComponents,
    required this.dataSources,
    required this.confidencePct,
    required this.score,
    required this.waterNotes,
  });
}