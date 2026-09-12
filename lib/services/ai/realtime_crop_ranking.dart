import 'dart:convert';

import 'package:vidhai/data/models/crop_plan_models.dart';

/// One crop, ranked by the realtime AI brain with a short farmer-facing reason.
class AiRankedCrop {
  final String cropName;
  final String reason;

  const AiRankedCrop({required this.cropName, required this.reason});
}

/// Validated output of a realtime AI ranking call. All crop names are clamped
/// to the engine-verified candidate set — the AI may reorder and explain, but
/// it can never introduce crops, scores or figures of its own.
class RealtimeCropRanking {
  final List<AiRankedCrop> rankedCrops;
  final String farmNote;

  const RealtimeCropRanking({
    required this.rankedCrops,
    this.farmNote = '',
  });
}

/// Pure prompt + strict JSON parser for the realtime crop-ranking step.
///
/// The generated prompt asks the AI brain to rank an engine-verified candidate
/// set using the farmer's real context, and to answer only with JSON. The
/// parser rejects any crop name that is not present in [allowedNames], so the
/// no-fake-data rule holds even if the model hallucinates.
class RealtimeCropRankingParser {
  RealtimeCropRankingParser._();

  static const int maxCrops = 10;

  /// Builds the farmer prompt (in the farmer's own language).
  static String buildPrompt(
    List<CropRecommendationResult> candidates,
    String language,
  ) {
    final langName = _languageName(language);
    final buffer = StringBuffer();

    buffer.writeln(
        'You are VidhAI, the on-device crop advisor of the VidhAI agricultural app (India).');
    buffer.writeln('Reply ONLY with valid JSON. Do not use markdown fences.');
    buffer.writeln('Respond in $langName.');
    buffer.writeln(
        'Below is the engine-verified shortlist of ${candidates.length} candidate crops for this farm, '
        'each with its score, sowing-calendar status, rotation analysis, duration, budget, profit '
        'margin and market demand. Prioritise crops that can still be sown now.');
    buffer.writeln(
        'Use only the facts below plus the provided "Farmer context" (soil, water, season, weather, '
        'planting history, market prices) to order the crops. Never invent data, numbers, crops or '
        'economic figures.');
    buffer.writeln();
    buffer.writeln('Candidates:');
    for (final c in candidates) {
      final cal = _calendarNote(c.calendarStatus);
      final margin = c.profitMarginPct != null
          ? ', margin ~${c.profitMarginPct!.round()}%'
          : '';
      final prices = c.money.revenueMax > 0
          ? ', est. revenue ₹${c.money.revenueMin}-₹${c.money.revenueMax}'
          : '';
      buffer.writeln(
          '- ${c.cropName} (score ${c.score}${c.confidence.isNotEmpty ? ', ${c.confidence}' : ''}'
          ', ${c.season}, ${c.durationLabel}$cal$margin$prices)');
      if (c.rotationAnalysis != null && c.rotationAnalysis!.isNotEmpty) {
        buffer.writeln('  rotation: ${c.rotationAnalysis}');
      }
    }
    buffer.writeln();
    buffer.writeln(
        'JSON schema: {"rankedCrops":[{"cropName":"exact candidate name","reason":"one '
        'actionable sentence, max 30 words"}],"farmNote":"one practical sentence for the '
        'whole farm, max 50 words"}');
    buffer.writeln(
        'rankedCrops must contain 3-$maxCrops crops, each cropName copied exactly from the '
        'candidates above, ordered from most to least suitable right now.');
    return buffer.toString();
  }

  static String _calendarNote(String? status) {
    switch (status) {
      case 'ideal_now':
        return ', sowing window open now';
      case 'sow_soon':
        return ', sowing window closing';
      case 'next_window':
        return ', next sowing window within months';
      case 'not_now':
        return ', not in sowing season now';
      default:
        return '';
    }
  }

  /// Parses and strictly validates the model reply. Returns null when the reply
  /// carries no usable, engine-verified ranking.
  static RealtimeCropRanking? parseResponse(
    String raw,
    Set<String> allowedNames,
  ) {
    if (raw.trim().isEmpty || allowedNames.isEmpty) return null;

    final upperAllowed = <String, String>{
      for (final name in allowedNames) name.trim().toLowerCase(): name,
    };

    final map = _extractJsonObject(raw);
    if (map == null) return null;

    final rawCrops = map['rankedCrops'];
    if (rawCrops is! List) return null;

    final ranked = <AiRankedCrop>[];
    final seen = <String>{};
    for (final entry in rawCrops.whereType<Map>()) {
      final rawName = (entry['cropName'] ?? '').toString().trim();
      final canonical = upperAllowed[rawName.toLowerCase()];
      if (canonical == null || !seen.add(canonical)) continue;
      final reason = (entry['reason'] ?? '').toString().trim();
      ranked.add(AiRankedCrop(cropName: canonical, reason: reason));
      if (ranked.length >= maxCrops) break;
    }

    if (ranked.isEmpty) return null;

    final farmNote = (map['farmNote'] ?? '').toString().trim();
    return RealtimeCropRanking(rankedCrops: ranked, farmNote: farmNote);
  }

  /// Tolerantly finds the top-level JSON object, even when the model wraps the
  /// answer in prose or markdown code fences.
  static Map<String, dynamic>? _extractJsonObject(String raw) {
    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*');
    if (text.startsWith('```')) text = text.replaceFirst(fence, '').trim();
    if (text.endsWith('```')) text = text.substring(0, text.length - 3).trim();

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;

    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return null;
    }
    return null;
  }

  static String _languageName(String language) {
    switch (language) {
      case 'ta':
        return 'Tamil';
      case 'te':
        return 'Telugu';
      case 'kn':
        return 'Kannada';
      case 'ml':
        return 'Malayalam';
      case 'hi':
        return 'Hindi';
      case 'bn':
        return 'Bengali';
      case 'mr':
        return 'Marathi';
      case 'gu':
        return 'Gujarati';
      case 'pa':
        return 'Punjabi';
      case 'or':
        return 'Odia';
      case 'as':
        return 'Assamese';
      case 'ur':
        return 'Urdu';
      default:
        return 'English';
    }
  }
}
