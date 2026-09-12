import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/ai/ai_context_builder.dart';
import 'package:vidhai/services/ai/ai_service.dart';

/// When-relevant, always-honest farm snapshot used by the Farm Details sheet.
///
/// The summary is derived exclusively from real stored records via
/// [AIContextBuilder]. An optional free-text AI narrative (in the farmer's
/// language) is requested from the secure backend; if the backend is
/// unavailable the UI falls back to the data points alone — never to invented
/// prose.
class FarmAiSummaryData {
  final String? aiNarrative;
  final bool online;
  final String season;
  final String? activeCrop;
  final String? cropStage;
  final int? cropProgressPct;
  final bool hasActiveCrop;
  final bool weatherAvailable;
  final String? weatherCondition;
  final double? temperature;
  final int? humidity;
  final bool heatAlert;
  final bool rainAlert;
  final bool marketAvailable;
  final int marketCount;
  final List<String> historyNames;
  final int expenseCount;
  final double expenseTotal;
  final DateTime generatedAt;
  final String contextHash;

  const FarmAiSummaryData({
    this.aiNarrative,
    this.online = false,
    required this.season,
    this.activeCrop,
    this.cropStage,
    this.cropProgressPct,
    this.hasActiveCrop = false,
    this.weatherAvailable = false,
    this.weatherCondition,
    this.temperature,
    this.humidity,
    this.heatAlert = false,
    this.rainAlert = false,
    this.marketAvailable = false,
    this.marketCount = 0,
    this.historyNames = const [],
    this.expenseCount = 0,
    this.expenseTotal = 0,
    required this.generatedAt,
    required this.contextHash,
  });

  FarmAiSummaryData copyWith({String? aiNarrative, bool online = false}) =>
      FarmAiSummaryData(
        aiNarrative: aiNarrative ?? this.aiNarrative,
        online: online,
        season: season,
        activeCrop: activeCrop,
        cropStage: cropStage,
        cropProgressPct: cropProgressPct,
        hasActiveCrop: hasActiveCrop,
        weatherAvailable: weatherAvailable,
        weatherCondition: weatherCondition,
        temperature: temperature,
        humidity: humidity,
        heatAlert: heatAlert,
        rainAlert: rainAlert,
        marketAvailable: marketAvailable,
        marketCount: marketCount,
        historyNames: historyNames,
        expenseCount: expenseCount,
        expenseTotal: expenseTotal,
        generatedAt: generatedAt,
        contextHash: contextHash,
      );
}

typedef FarmSummaryNarrative = Future<String?> Function(
    AiContextSnapshot snapshot, String? languageCode);

class FarmAiSummaryService {
  FarmAiSummaryService({
    AIContextBuilder? contextBuilder,
    FarmSummaryNarrative? narrativeProvider,
  })  : _contextBuilder = contextBuilder ?? AIContextBuilder(),
        _narrativeProvider = narrativeProvider ?? _requestNarrative;

  static final FarmAiSummaryService instance = FarmAiSummaryService();

  final AIContextBuilder _contextBuilder;
  final FarmSummaryNarrative _narrativeProvider;

  Future<FarmAiSummaryData> summarize(FarmProfile farm,
      {String? languageCode}) async {
    final snapshot =
        await _contextBuilder.build(farm: farm, languageCode: languageCode);
    final season = snapshot.season;
    final crop = snapshot.activeCrop;
    final stageInfo = snapshot.stageInfo;
    final weather = snapshot.weather;

    var expenseTotal = 0.0;
    for (final e in snapshot.expenses) {
      expenseTotal += e.amount;
    }

    final summary = FarmAiSummaryData(
      season: season,
      activeCrop: crop?.cropName,
      cropStage: stageInfo['stage'] as String?,
      cropProgressPct: stageInfo['progress'] as int?,
      hasActiveCrop: crop != null,
      weatherAvailable: weather.isNotEmpty,
      weatherCondition: weather['condition'] as String?,
      temperature: weather['temperature'] as double?,
      humidity: weather['humidity'] as int?,
      heatAlert: weather['heatAlert'] as bool? ?? false,
      rainAlert: weather['rainAlert'] as bool? ?? false,
      marketAvailable: snapshot.marketContext.isNotEmpty,
      marketCount: snapshot.marketContext.length,
      historyNames:
          snapshot.cropHistory.take(6).map((c) => c.cropName).toList(),
      expenseCount: snapshot.expenses.length,
      expenseTotal: expenseTotal,
      generatedAt: DateTime.now(),
      contextHash: snapshot.contextHash,
    );

    final narrative = await _narrativeProvider(snapshot, languageCode);
    if (narrative == null) return summary;
    return summary.copyWith(aiNarrative: narrative, online: true);
  }

  static Future<String?> _requestNarrative(
      AiContextSnapshot snapshot, String? languageCode) async {
    try {
      final lang = languageCode ?? 'en';
      final prompt =
          'You are VidhAI. Write exactly three short factual sentences (in '
          '${snapshot.languageName}) summarising this farm right now. Use ONLY '
          'the provided context. Mention the active crop and its stage, the '
          'season, and one practical suggestion. Do not invent data. Do not use '
          'bullets.';
      final response = await AiService.instance
          .chat(prompt, language: lang, context: snapshot.toBackendContext())
          .timeout(const Duration(seconds: 12));
      if (response.success && response.content.trim().isNotEmpty) {
        return response.content.trim();
      }
    } catch (e) {
      debugPrint('[FarmAiSummaryService] narrative skipped (offline): $e');
    }
    return null;
  }
}
