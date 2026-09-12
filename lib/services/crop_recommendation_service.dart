import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vidhai/core/config/app_config.dart';
import 'package:vidhai/core/connectivity/connectivity_service.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/models/ai/ai_message.dart';
import 'package:vidhai/services/ai/ai_chat_brain.dart';
import 'package:vidhai/services/ai/ai_context_builder.dart';
import 'package:vidhai/services/ai/realtime_crop_ranking.dart';
import 'package:vidhai/services/crop_backend_service.dart';
import 'package:vidhai/services/crop_knowledge_base.dart';
import 'package:vidhai/services/crop_plan_generator.dart';
import 'package:vidhai/services/data_service.dart';
import 'package:vidhai/services/farm_recommendation_service.dart';

/// Orchestrates the crop-planning feature:
///   1. Online: structured engine via the VidhAI backend (`/crop/*`).
///   2. Offline: deterministic local knowledge-base fallback.
///   3. AI narrative (when online) reuses the existing secure `/ai/chat` relay.
///
/// Every run is recorded (recommendation runs, manual checks) so crop history,
/// comparisons and the Workspace stay populated after offline sessions.
class CropRecommendationService {
  CropRecommendationService._();
  static final CropRecommendationService _instance =
      CropRecommendationService._();
  static CropRecommendationService get instance => _instance;

  final DataService _dataService = DataService();
  final CropKnowledgeBase _knowledgeBase = CropKnowledgeBase();
  final FarmRecommendationService _localService = FarmRecommendationService();
  final AIContextBuilder _contextBuilder = AIContextBuilder();

  /// Budget for a realtime AI call before falling back to local results.
  static const Duration _aiTimeout = Duration(seconds: 20);

  // ── Context snapshot (single source of truth for the AI layer) ─────────

  Future<AiContextSnapshot> _buildSnapshot(FarmProfile farm) async {
    try {
      return await _contextBuilder.build(farm: farm);
    } catch (e) {
      debugPrint('[CropRecommendationService] context snapshot degraded: $e');
      return AiContextSnapshot.basic(farm: farm);
    }
  }

  Map<String, dynamic> recommendationInput(CropSetupQuestionnaire q) => {
        'waterAvailability': q.waterAvailability,
        'soilType': q.soilType,
        'irrigationSystem': q.irrigationSystem,
        'farmLocation': q.farmLocation,
        'currentSeason': q.currentSeason,
        'cropDurationPreference': q.cropDurationPreference,
        'cropCategoryPreference': q.cropCategoryPreference,
        'budgetInrPerAcre': q.budgetInrPerAcre,
        'lastCrop': q.lastCrop,
        'landIdleDuration': q.landIdleDuration,
      };

  /// Returns the preferred top-10 crop recommendations for the farm.
  ///
  /// Order of sources:
  ///   1. Live online `/crop/recommend` (backed by the real context bundle).
  ///   2. Cached online results — only when the decision context hash is
  ///      unchanged and within the TTL (never a stale/mismatched fabrication).
  ///   3. Realtime AI ranking (Groq, when a key is compiled in and online) on
  ///      top of the engine-verified shortlist — reorders and explains only.
  ///   4. Deterministic local knowledge-base engine.
  Future<List<CropRecommendationResult>> getRecommendations({
    required FarmProfile farm,
    required CropSetupQuestionnaire questionnaire,
  }) async {
    debugPrint('[CropRecommendationService] getRecommendations: farmId=${farm.farmId} '
        'farm=${farm.farmName} location=${farm.farmLocation?.fullAddress ?? '-'} '
        'state=${farm.farmLocation?.state ?? '-'} district=${farm.farmLocation?.district ?? '-'} '
        'acres=${farm.farmSize}${farm.farmSizeUnit} soil=${farm.soilType} '
        'water=${farm.waterAvailability} irrigation=${farm.irrigationType}');
    debugPrint('[CropRecommendationService] request payload: '
        '${json.encode(recommendationInput(questionnaire))}');

    final snapshot = await _buildSnapshot(farm);
    final hash = snapshot.contextHash;

    final online = await CropBackendService.instance.fetchTop10(
      farm: snapshot.farmMap,
      input: recommendationInput(questionnaire),
      contextHash: hash,
    );
    if (online != null) {
      if (online.isEmpty) {
        debugPrint(
            '[CropRecommendationService] online returned 0 crops — falling through to cache/local');
      } else {
        debugPrint('[CropRecommendationService] online: ${online.length} crops '
            '(${online.map((r) => r.cropName).take(10).join(', ')})');
        return _dedupeTop10(online);
      }
    } else {
      debugPrint('[CropRecommendationService] online unavailable (offline or error)');
    }

    final cached = await CropBackendService.instance
        .cachedTop10(farm.farmId, contextHash: hash);
    if (cached != null) {
      debugPrint('[CropRecommendationService] cache hit: ${cached.length} crops');
      return _dedupeTop10(cached);
    }
    debugPrint('[CropRecommendationService] cache miss');

    final local = _localRecommendationFallback(farm, questionnaire, snapshot);
    if (local.isEmpty) {
      debugPrint('[CropRecommendationService] local fallback returned 0 crops');
      return local;
    }
    debugPrint('[CropRecommendationService] local fallback: ${local.length} crops '
        '(${local.map((r) => r.cropName).take(10).join(', ')})');

    final ranked = await _realtimeRank(
      candidates: local,
      snapshot: snapshot,
      language: await _dataService.getSelectedLanguage(),
    );
    final finalRanked = ranked ?? local;
    debugPrint('[CropRecommendationService] returning ${finalRanked.length} crops '
        '(source: ${ranked != null ? 'realtime AI' : 'local'})');
    return finalRanked;
  }

  // ── Realtime AI ranking (online, best-effort) ──────────────────────────────

  /// Ranks the engine-verified shortlist with the realtime AI brain using the
  /// farmer's real context. Returns null on any failure/timeout so the caller
  /// keeps the deterministic local results.
  Future<List<CropRecommendationResult>?> _realtimeRank({
    required List<CropRecommendationResult> candidates,
    required AiContextSnapshot snapshot,
    required String language,
  }) async {
    if (AppConfig.groqApiKey.isEmpty) return null;
    try {
      if (!await ConnectivityService.hasInternetConnection()) return null;
      final prompt =
          RealtimeCropRankingParser.buildPrompt(candidates, language);
      final reply = await AiChatBrain.chat(
        messages: [AIMessage.user(prompt)],
        language: language,
        context: snapshot.toBackendContext(),
        timeout: _aiTimeout,
      );
      if (!reply.success || reply.content.trim().isEmpty) return null;
      final parsed = RealtimeCropRankingParser.parseResponse(
        reply.content,
        candidates.map((c) => c.cropName).toSet(),
      );
      if (parsed == null) return null;
      return _applyRanking(candidates, parsed);
    } catch (e) {
      debugPrint('[CropRecommendationService] realtime AI ranking skipped: $e');
      return null;
    }
  }

  /// Applies an AI ordering to the verified candidates, keeping every score,
  /// budget and duration figure exactly as the engine produced it.
  List<CropRecommendationResult> _applyRanking(
      List<CropRecommendationResult> candidates, RealtimeCropRanking ranking) {
    final byName = <String, CropRecommendationResult>{
      for (final c in candidates) c.cropName.toLowerCase(): c,
    };
    final ordered = <CropRecommendationResult>[];
    final used = <String>{};
    for (final ranked in ranking.rankedCrops) {
      final match = byName[ranked.cropName.toLowerCase()];
      if (match == null || !used.add(match.cropName.toLowerCase())) continue;
      ordered.add(_withRankAndReason(
        match,
        rank: ordered.length + 1,
        reason: ranked.reason,
      ));
    }
    for (final c in candidates) {
      if (used.add(c.cropName.toLowerCase())) {
        ordered.add(_withRankAndReason(c, rank: ordered.length + 1));
      }
    }
    return ordered.length > 10 ? ordered.sublist(0, 10) : ordered;
  }

  CropRecommendationResult _withRankAndReason(
    CropRecommendationResult base, {
    required int rank,
    String? reason,
  }) {
    final hasReason = reason != null && reason.isNotEmpty;
    return CropRecommendationResult(
      rank: rank,
      cropId: base.cropId,
      cropName: base.cropName,
      varieties: base.varieties,
      category: base.category,
      season: base.season,
      durationMin: base.durationMin,
      durationMax: base.durationMax,
      score: base.score,
      confidence: base.confidence,
      budget: base.budget,
      money: base.money,
      factors: base.factors,
      strengths: hasReason ? [reason] : base.strengths,
      concerns: base.concerns,
      waterNotes: base.waterNotes,
      plantingWindow: base.plantingWindow,
      harvestHint: base.harvestHint,
      risks: base.risks,
      pests: base.pests,
      diseases: base.diseases,
      marketDemand: base.marketDemand,
      riskLevel: base.riskLevel,
      description: hasReason ? reason : base.description,
      estimatedLabel: base.estimatedLabel,
      calendarStatus: base.calendarStatus,
      sowingWindow: base.sowingWindow,
      harvestWindowLocal: base.harvestWindowLocal,
      rotationAnalysis: base.rotationAnalysis,
      previousCrop: base.previousCrop,
      riskExplanation: base.riskExplanation,
      riskScore: base.riskScore,
      costBreakdown: base.costBreakdown,
      costPerAcre: base.costPerAcre,
      revenuePerAcre: base.revenuePerAcre,
      profitPerAcre: base.profitPerAcre,
      profitMarginPct: base.profitMarginPct,
      farmAreaAcres: base.farmAreaAcres,
      totalCost: base.totalCost,
      totalRevenue: base.totalRevenue,
      totalProfit: base.totalProfit,
      yieldPerAcreKg: base.yieldPerAcreKg,
      weatherAvailability: base.weatherAvailability,
      marketPricePerKg: base.marketPricePerKg,
      marketPriceSource: base.marketPriceSource,
      marketPriceDate: base.marketPriceDate,
      scoreComponents: base.scoreComponents,
      dataSources: base.dataSources,
      confidencePct: base.confidencePct,
    );
  }

  // ── Manual crop check ──────────────────────────────────────────────────────

  Future<ManualCropCheck> manualCheck({
    required FarmProfile farm,
    required String cropName,
    String? variety,
  }) async {
    final snapshot = await _buildSnapshot(farm);
    final online = await CropBackendService.instance.checkCrop(
      farm: snapshot.farmMap,
      cropName: cropName,
      variety: variety,
      farmId: farm.farmId,
    );
    if (online != null) {
      await _dataService.saveManualCropCheck(online);
      return online;
    }
    final local = _localManualCheckFallback(farm, cropName, variety);
    await _dataService.saveManualCropCheck(local);
    return local;
  }

  // ── Start crop flow ────────────────────────────────────────────────────────

  /// Persists the crop, generates the dated to-do plan, an optional AI
  /// narrative and a recommendation record, then wires them to the Workspace.
  Future<CropPlan> startCrop({
    required FarmProfile farm,
    required CropRecommendationResult recommendation,
    DateTime? startDate,
    String? varietyOverride,
  }) async {
    final cropId = _dataService.generateId();
    final plan = CropPlanGenerator().buildPlan(
      farm: farm,
      recommendation: recommendation,
      cropId: cropId,
      startDate: startDate,
      varietyOverride: varietyOverride,
    );

    final cropRecord = CropRecord(
      id: cropId,
      farmId: farm.farmId,
      cropName: recommendation.cropName,
      variety: plan.variety,
      category: recommendation.category,
      duration:
          '${recommendation.durationMin}-${recommendation.durationMax} days',
      plantingDate: plan.startDate,
      expectedHarvestDate: plan.estimatedHarvestDate,
      status: 'active',
      recommendationScore: recommendation.score.toDouble(),
      recommendationSource: 'ai',
      cropPlanId: plan.cropId,
      notes: 'AI-recommended crop plan',
    );
    await _dataService.saveCrop(cropRecord);

    // AI narrative (optional, online only) — never blocks the flow.
    final narrative = await _aiNarrative(
      cropName: recommendation.cropName,
      variety: plan.variety,
      farm: farm,
    );
    final finalPlan =
        narrative == null ? plan : plan.copyWith(whyRecommended: narrative);

    await _dataService.saveCropPlan(finalPlan);
    await _dataService.saveCropTasks(CropPlanGenerator().buildTasks(finalPlan));

    // Record the recommendation run with the selected crop marked.
    final records = await _dataService.loadRecommendationRecords(farm.farmId);
    if (records.isNotEmpty) {
      final latest = records.first;
      final updated = RecommendationRecord(
        id: latest.id,
        farmId: latest.farmId,
        state: latest.state,
        createdAt: latest.createdAt,
        input: latest.input,
        top10: latest.top10,
        selectedCropId: recommendation.cropId,
        selectedCropName: recommendation.cropName,
      );
      await _dataService.saveRecommendationRecord(updated);
    }
    return finalPlan;
  }

  /// Starts a crop chosen through the manual-crop-check flow.
  Future<CropPlan> startManualCrop({
    required FarmProfile farm,
    required ManualCropCheck check,
    DateTime? startDate,
  }) async {
    final result = CropRecommendationResult(
      rank: 1,
      cropId: check.matchedCrop.isNotEmpty ? check.matchedCrop : check.cropName,
      cropName: check.cropName,
      varieties: [
        if (check.variety != null && check.variety!.isNotEmpty) check.variety!
      ],
      category: _categoryFromCheck(check),
      season: _seasonFromCheck(check),
      durationMin: _durationMinFromCheck(check),
      durationMax: _durationMaxFromCheck(check),
      score: check.score,
      confidence: check.score >= 80
          ? 'High'
          : check.score >= 60
              ? 'Medium'
              : 'Low',
      budget: const CropBudgetEstimate(
        classification: 'Not Specified',
        cultivationCostMin: 0,
        cultivationCostMax: 0,
        seedCostMin: 0,
        seedCostMax: 0,
      ),
      money: const CropMoneyEstimate(
        yieldMin: 0,
        yieldMax: 0,
        yieldUnit: '',
        revenueMin: 0,
        revenueMax: 0,
        profitMin: 0,
        profitMax: 0,
      ),
      factors: check.factors
          .map((f) => RecommendationFactor(
              name: f.label,
              weight: 1,
              score: f.verdict == 'Excellent'
                  ? 0.9
                  : f.verdict == 'Potential Concern'
                      ? 0.5
                      : 0.2,
              detail: f.label))
          .toList(),
      strengths: check.strengths,
      concerns: check.concerns,
      waterNotes: '',
      plantingWindow: check.seasonNotes,
      harvestHint: '',
      risks: check.concerns,
      pests: const [],
      diseases: const [],
      marketDemand: '',
      riskLevel: check.score >= 50 ? 'Medium' : 'High',
      description: check.reason,
      estimatedLabel: true,
    );
    return startCrop(farm: farm, recommendation: result, startDate: startDate);
  }

  // ── Local fallbacks (offline) ──────────────────────────────────────────────

  List<CropRecommendationResult> _localRecommendationFallback(
      FarmProfile farm, CropSetupQuestionnaire questionnaire,
      [AiContextSnapshot? snapshot]) {
    final farmSizeAcres = snapshot?.farmMap['farmSizeAcres'];
    final localRecs = _localService.getRecommendations(
      farm: farm,
      questionnaire: questionnaire,
      marketContext: snapshot?.marketContext,
      previousCrops:
          snapshot?.cropHistory.map((c) => c.cropName.trim()).toList(),
      weather: snapshot?.weather,
      farmAreaAcres: farmSizeAcres is num ? farmSizeAcres.toDouble() : null,
    );
    if (localRecs.isEmpty) return const [];
    final results = <CropRecommendationResult>[];
    for (var i = 0; i < localRecs.length && i < 10; i++) {
      final rec = localRecs[i];
      final entry = _knowledgeBase.allCrops
          .where((c) =>
              c.id == rec.cropId ||
              c.name.toLowerCase() == rec.cropName.toLowerCase())
          .firstOrNull;
      results.add(_fromLocalRec(rec, entry, rank: i + 1));
    }
    return results;
  }

  CropRecommendationResult _fromLocalRec(
      CropRecommendation rec, CropKnowledgeEntry? entry,
      {required int rank}) {
    int? budgetCost = entry == null
        ? null
        : int.tryParse(
            entry.investmentPerAcre.replaceAll(RegExp(r'[^0-9]'), ''));
    if (budgetCost == null || budgetCost <= 0) {
      budgetCost = rec.estimatedInvestment.isEmpty
          ? 0
          : int.tryParse(
                  rec.estimatedInvestment.replaceAll(RegExp(r'[^0-9]'), '')) ??
              0;
    }
    int? revenue = entry == null
        ? null
        : int.tryParse(entry.revenuePerAcre.replaceAll(RegExp(r'[^0-9]'), ''));
    if (revenue == null || revenue <= 0) {
      revenue = budgetCost + (budgetCost ~/ 3);
    }
    final cost = budgetCost;
    return CropRecommendationResult(
      rank: rank,
      cropId: rec.cropId,
      cropName: rec.cropName,
      varieties: [rec.variety],
      category: rec.category,
      season: entry?.season ?? 'all',
      durationMin: _durationDaysToInt(rec.duration),
      durationMax: _durationDaysToInt(rec.duration),
      score: rec.score.round().clamp(0, 100),
      confidence: rec.score >= 70
          ? 'High'
          : rec.score >= 55
              ? 'Medium'
              : 'Low',
      budget: CropBudgetEstimate(
        classification: 'Not Specified',
        cultivationCostMin: cost,
        cultivationCostMax: cost,
        seedCostMin: 0,
        seedCostMax: 0,
      ),
      money: CropMoneyEstimate(
        yieldMin: 0,
        yieldMax: 0,
        yieldUnit: entry?.expectedYieldPerAcre ?? '',
        revenueMin: revenue,
        revenueMax: revenue + (revenue ~/ 4),
        profitMin: (revenue - cost).clamp(0, 1 << 30),
        profitMax: (revenue - cost + (revenue ~/ 4)).clamp(0, 1 << 30),
      ),
      factors: const [],
      strengths: [rec.whyRecommended],
      concerns: const [],
      waterNotes:
          'Water requirement: ${entry?.waterRequirement ?? rec.waterRequirement}.',
      plantingWindow: rec.bestPlantingPeriod,
      harvestHint: rec.expectedHarvestPeriod,
      risks: const [],
      pests: const [],
      diseases: const [],
      marketDemand: rec.marketAvailability,
      riskLevel: rec.riskLevel,
      description: entry?.description ?? '',
      estimatedLabel: true,
      calendarStatus: rec.calendarStatus,
      sowingWindow: rec.sowingWindow,
      harvestWindowLocal: rec.harvestWindowLocal,
      rotationAnalysis: rec.rotationAnalysis,
      previousCrop: rec.previousCrop,
      riskExplanation: rec.riskExplanation,
      riskScore: rec.riskScore,
      costBreakdown: rec.costBreakdown,
      costPerAcre: rec.costPerAcre,
      revenuePerAcre: rec.revenuePerAcre,
      profitPerAcre: rec.profitPerAcre,
      profitMarginPct: rec.profitMarginPct,
      farmAreaAcres: rec.farmAreaAcres,
      totalCost: rec.totalCost,
      totalRevenue: rec.totalRevenue,
      totalProfit: rec.totalProfit,
      yieldPerAcreKg: rec.yieldPerAcreKg,
      weatherAvailability: rec.weatherAvailability,
      marketPricePerKg: rec.marketPricePerKg,
      marketPriceSource: rec.marketPriceSource,
      marketPriceDate: rec.marketPriceDate,
      scoreComponents: rec.scoreComponents,
      dataSources: rec.dataSources,
      confidencePct: rec.confidencePct,
    );
  }

  ManualCropCheck _localManualCheckFallback(
      FarmProfile farm, String cropName, String? variety) {
    final q = cropName.trim().toLowerCase();
    final entry = _knowledgeBase.allCrops
        .where((c) => c.name.toLowerCase() == q)
        .firstOrNull;
    if (entry == null) {
      return ManualCropCheck(
        id: _dataService.generateId(),
        farmId: farm.farmId,
        cropName: cropName,
        variety: variety,
        score: 0,
        verdict: 'Not Recommended',
        matchedCrop: cropName,
        createdAt: DateTime.now(),
        factors: const [],
        estimates: const [],
        strengths: const [],
        concerns: const ['Crop not found in the verified offline database.'],
        reason:
            'Insufficient verified information for "$cropName". Connect to the internet for the full knowledge base.',
        seasonNotes: '',
        regionNotes: '',
        found: false,
      );
    }
    final stateMatch = entry.suitableStates.any((s) =>
        s.toLowerCase() == (farm.farmLocation?.state ?? '').toLowerCase());
    return ManualCropCheck(
      id: _dataService.generateId(),
      farmId: farm.farmId,
      cropName: entry.name,
      variety: variety ?? entry.variety,
      score: stateMatch ? 72 : 55,
      verdict: stateMatch ? 'Suitable' : 'Moderately Suitable',
      matchedCrop: entry.name,
      createdAt: DateTime.now(),
      factors: [
        ManualCheckFactor(
            label: 'State fit',
            verdict: stateMatch ? 'Excellent' : 'Potential Concern'),
        ManualCheckFactor(
            label: 'Season fit',
            verdict: entry.season.toLowerCase() == 'all'
                ? 'Excellent'
                : 'Excellent'),
      ],
      estimates: [
        CheckEstimate(
            label: 'Duration', value: entry.durationDays, accuracy: 'Verified'),
        CheckEstimate(
            label: 'Investment (est.)',
            value: entry.investmentPerAcre,
            accuracy: 'Estimated'),
        CheckEstimate(
            label: 'Expected yield (est.)',
            value: entry.expectedYieldPerAcre,
            accuracy: 'Estimated'),
      ],
      strengths: [
        'Known to grow in: ${entry.suitableStates.take(5).join(', ')}'
      ],
      concerns:
          stateMatch ? const [] : ['Not commonly reported in your state.'],
      reason: stateMatch
          ? 'Looks like a viable option for this farm.'
          : 'Cultivated elsewhere in India; verify local suitability.',
      seasonNotes:
          'Best planting: ${entry.bestPlantingMonth}. Harvest: ${entry.harvestMonth}.',
      regionNotes: 'Grown in: ${entry.suitableStates.take(6).join(', ')}.',
      found: true,
    );
  }

  // ── AI narrative (online, best-effort) ─────────────────────────────────────

  Future<String?> _aiNarrative({
    required String cropName,
    required String variety,
    required FarmProfile farm,
  }) async {
    try {
      final prompt =
          'In one short paragraph (60-90 words), explain why $cropName ($variety) is a sensible '
          'crop choice right now for a farm in ${farm.farmLocation?.state ?? 'India'} with '
          "${farm.soilType.isNotEmpty ? '$farm.soilType soil' : 'mixed soil'}, "
          "${farm.irrigationType.isNotEmpty ? '$farm.irrigationType irrigation' : 'field irrigation'} and "
          "${farm.waterAvailability.isNotEmpty ? '$farm.waterAvailability water availability' : 'limited water records'}. "
          'Start with "Why this crop:" and end with a single practical caution. Keep it factual and simple.';
      final reply = await AiChatBrain.chat(
        messages: [AIMessage.user(prompt)],
        language: await _dataService.getSelectedLanguage(),
        timeout: _aiTimeout,
      );
      if (reply.success && reply.content.trim().isNotEmpty) {
        return reply.content.trim();
      }
    } catch (e) {
      debugPrint('[CropRecommendationService] AI narrative skipped: $e');
    }
    return null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<CropRecommendationResult> _dedupeTop10(
      List<CropRecommendationResult> list) {
    final seen = <String>{};
    final out = <CropRecommendationResult>[];
    for (final r in list) {
      if (seen.add(r.cropId)) out.add(r);
      if (out.length == 10) break;
    }
    return out;
  }

  int _durationDaysToInt(String duration) {
    final value = int.tryParse(
        duration.replaceAll(RegExp(r'[^0-9-]'), '').split('-').last);
    return value == null || value <= 0 ? 120 : value;
  }

  String _categoryFromCheck(ManualCropCheck check) {
    for (final e in check.estimates) {
      if (e.label.toLowerCase().contains('duration')) {
        return check.matchedCrop.split(' ').first;
      }
    }
    return '';
  }

  String _seasonFromCheck(ManualCropCheck check) {
    final lower = check.seasonNotes.toLowerCase();
    if (lower.contains('kharif')) return 'Kharif';
    if (lower.contains('rabi')) return 'Rabi';
    if (lower.contains('zaid')) return 'Zaid';
    return '';
  }

  int _durationMinFromCheck(ManualCropCheck check) {
    for (final e in check.estimates) {
      if (e.label.toLowerCase().contains('duration')) {
        final m = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(e.value);
        if (m != null) return int.parse(m.group(1)!);
        final single = RegExp(r'\d+').firstMatch(e.value);
        if (single != null) return int.parse(single.group(0)!);
      }
    }
    return 120;
  }

  int _durationMaxFromCheck(ManualCropCheck check) {
    for (final e in check.estimates) {
      if (e.label.toLowerCase().contains('duration')) {
        final m = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(e.value);
        if (m != null) return int.parse(m.group(2)!);
        final single = RegExp(r'\d+').firstMatch(e.value);
        if (single != null) return int.parse(single.group(0)!);
      }
    }
    return 150;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
