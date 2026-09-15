import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/services/ai/secure_api_client.dart';

/// Online crop-data access through the VidhAI secure backend (`/crop/*`).
/// The client never ships a crop database key; all figures returned are
/// server reference estimates and are labelled as such by the UI.
///
/// Every call is mirrored into a small SharedPreferences cache so the Guides
/// and the recommendation flow stay usable offline.
class CropBackendService {
  CropBackendService._();
  static final CropBackendService instance = CropBackendService._();

  static const _timeout = Duration(seconds: 45);

  bool _lastOnline = false;
  bool get wasLastCallOnline => _lastOnline;

  // ── Recommendation ─────────────────────────────────────────────────────────

  Future<List<CropRecommendationResult>?> fetchTop10({
    required Map<String, dynamic> farm,
    required Map<String, dynamic> input,
    String? contextHash,
  }) async {
    try {
      final body = await SecureApiClient.instance
          .post('/crop/recommend', {'farm': farm, 'input': input},
              debugTag: 'crop/recommend')
          .timeout(_timeout);
      _lastOnline = true;
      final top10 = (body['top10'] as List? ?? const [])
          .map((e) {
            try {
              return CropRecommendationResult.fromMap(e as Map<String, dynamic>);
            } catch (pe) {
              debugPrint(
                  '[CropBackendService] parse error in /crop/recommend item: $pe');
              rethrow;
            }
          })
          .toList();
      if (top10.isNotEmpty) {
        await _cacheTop10(farm['farmId'] as String? ?? '', body,
            contextHash: contextHash);
      }
      debugPrint('[CropBackendService] /crop/recommend returned '
          '${top10.length} crops');
      return top10;
    } catch (e) {
      _lastOnline = false;
      debugPrint(
          '[CropBackendService] recommend failed (offline fallback): $e');
      return null;
    }
  }

  // ── AI recommendation (Groq, structured output) ────────────────────────────

  /// Structured AI top-10 via the secure backend `/crop/ai-recommend`.
  ///
  /// [context] is the full auto-collected bundle (farm profile, soil, water,
  /// irrigation, crop history, season, weather, market prices) and [input] the
  /// ~6 manual farmer inputs. Never reaches the client raw — the server
  /// enforces the JSON Schema and the mapping below guarantees the result
  /// always adheres to [CropRecommendationResult].
  Future<List<CropRecommendationResult>?> fetchAIRecommendations({
    required Map<String, dynamic> context,
    required Map<String, dynamic> input,
  }) async {
    try {
      final body = await SecureApiClient.instance
          .post('/crop/ai-recommend', {
            'context': context,
            'input': input,
          }, debugTag: 'crop/ai-recommend')
          .timeout(_timeout);
      _lastOnline = true;
      if (body['success'] != true) return null;
      final raw = (body['recommendations'] as List? ?? const []);
      final modelLabel = (body['model'] as String?)?.isNotEmpty == true
          ? '${body['model']} via secure backend'
          : 'Groq GPT-OSS-20B via secure backend';
      final mapped = mapAIRecommendations(raw, dataSourceLabel: modelLabel);
      debugPrint('[CropBackendService] /crop/ai-recommend returned '
          '${mapped.length} crops (model ${body['model'] ?? '?'})');
      return mapped;
    } catch (e) {
      _lastOnline = false;
      debugPrint(
          '[CropBackendService] ai-recommend failed (offline fallback): $e');
      return null;
    }
  }

  /// Converts the strictly-validated AI JSON payload into the standard
  /// [CropRecommendationResult] shape used by the recommendation flow.
  static List<CropRecommendationResult> mapAIRecommendations(
      List<dynamic> raw,
      {String dataSourceLabel = 'Groq GPT-OSS-20B via secure backend'}) {
    final results = <CropRecommendationResult>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = item as Map<String, dynamic>;
      final name = (m['cropName'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;

      final dur = (m['estimatedDurationDays'] as num?)?.toInt() ?? 0;
      final score = (m['suitabilityScore'] as num?)?.toInt() ?? 0;

      List<int> range(String key) {
        final v = m[key];
        if (v is! Map) return const [0, 0];
        final min = (v['min'] as num?)?.toInt() ?? 0;
        final max = (v['max'] as num?)?.toInt() ?? min;
        return [
          min.clamp(0, 10000000),
          max.clamp(min.clamp(0, 10000000), 10000000)
        ];
      }

      final factors = <RecommendationFactor>[];
      void addFactor(String name, String detail) {
        if (detail.trim().isEmpty) return;
        factors.add(RecommendationFactor(
            name: name, weight: 1, score: 0.8, detail: detail.trim()));
      }

      addFactor('soil', (m['soilMatch'] as String?) ?? '');
      addFactor('water', (m['waterMatch'] as String?) ?? '');
      addFactor('season', (m['seasonMatch'] as String?) ?? '');
      addFactor('rotation', (m['rotationMatch'] as String?) ?? '');

      final strengths =
          ((m['whySuitable'] as List?) ?? const []).cast<String>().toList();
      final risks =
          ((m['majorRisks'] as List?) ?? const []).cast<String>().toList();
      final confidence = (m['confidence'] as num?)?.toInt() ?? 0;

      final investment = range('estimatedInvestment');
      final revenue = range('estimatedRevenue');
      final profit = range('estimatedProfit');

      final confidenceLabel = score >= 80
          ? 'High'
          : score >= 60
              ? 'Medium'
              : 'Low';

      final riskLevel = switch (m['riskLevel']) {
        'Low' => 'Low',
        'High' => 'High',
        _ => 'Medium',
      };

      results.add(CropRecommendationResult(
        rank: results.length + 1,
        cropId: '_ai_${(m['cropName'] as String?) ?? ''}',
        cropName: name,
        varieties: [(m['localName'] as String?) ?? ''],
        category: (m['cropName'] as String?) ?? '',
        season: '',
        durationMin: dur,
        durationMax: dur,
        score: score,
        confidence: confidenceLabel,
        budget: CropBudgetEstimate(
          classification: 'Not Specified',
          cultivationCostMin: investment[0],
          cultivationCostMax: investment[1],
          seedCostMin: 0,
          seedCostMax: 0,
        ),
        money: CropMoneyEstimate(
          yieldMin: 0,
          yieldMax: 0,
          yieldUnit: '',
          revenueMin: revenue[0],
          revenueMax: revenue[1],
          profitMin: profit[0],
          profitMax: profit[1],
        ),
        factors: factors,
        strengths: [...strengths],
        concerns: [...risks],
        waterNotes: (m['waterRequirement'] as String?) ?? '',
        plantingWindow: (m['sowingWindow'] as String?) ?? '',
        harvestHint: (m['estimatedHarvestWindow'] as String?) ?? '',
        risks: [...risks],
        pests: const [],
        diseases: const [],
        marketDemand: (m['marketOutlook'] as String?) ?? '',
        riskLevel: riskLevel,
        description: strengths.join(' '),
        estimatedLabel: true,
        dataSources: [dataSourceLabel],
        confidencePct: (confidence > 0 ? confidence : score).toDouble(),
      ));
    }
    return results;
  }

  // ── Manual check ───────────────────────────────────────────────────────────

  Future<ManualCropCheck?> checkCrop({
    required Map<String, dynamic> farm,
    required String cropName,
    String? variety,
    String? farmId,
  }) async {
    try {
      final body = await SecureApiClient.instance.post('/crop/check', {
        'farm': farm,
        'query': {
          'cropName': cropName,
          if (variety != null && variety.isNotEmpty) 'variety': variety
        },
      }).timeout(_timeout);
      _lastOnline = true;
      final check = ManualCropCheck.fromMap({...body, 'farmId': farmId ?? ''});
      return check;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[CropBackendService] check failed (offline fallback): $e');
      return null;
    }
  }

  // ── Catalog search ─────────────────────────────────────────────────────────

  Future<List<CropCatalogItem>> search({
    String? query,
    String? category,
    String? state,
    int limit = 30,
  }) async {
    try {
      final body = await SecureApiClient.instance.post('/crop/search', {
        if (query != null && query.isNotEmpty) 'query': query,
        if (category != null && category.isNotEmpty) 'category': category,
        if (state != null && state.isNotEmpty) 'state': state,
        'limit': limit,
      }).timeout(_timeout);
      _lastOnline = true;
      final items = (body['crops'] as List? ?? const [])
          .map((e) => CropCatalogItem.fromMap(e as Map<String, dynamic>))
          .toList();
      return items;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[CropBackendService] search failed (offline fallback): $e');
      return const [];
    }
  }

  // ── Offline mirrors (context-hash aware) ───────────────────────────────────

  static const _cacheTtl = Duration(days: 14);

  Future<void> _cacheTop10(String farmId, Map<String, dynamic> body,
      {String? contextHash}) async {
    if (farmId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final envelope = {
      'payload': body,
      if (contextHash != null) 'contextHash': contextHash,
      'fetchedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString('crop_top10_$farmId', json.encode(envelope));
  }

  Future<Map<String, dynamic>?> loadCachedTop10(String farmId,
      {String? contextHash}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('crop_top10_$farmId');
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      // Legacy cache format (raw payload, no envelope)
      if (decoded.containsKey('top10')) return decoded;

      // New envelope format: enforce context hash + TTL
      if (contextHash != null) {
        final stored = decoded['contextHash'] as String?;
        if (stored != null && stored != contextHash) return null;
      }
      final fetchedAt = DateTime.tryParse(decoded['fetchedAt'] ?? '');
      if (fetchedAt != null &&
          DateTime.now().difference(fetchedAt) > _cacheTtl) {
        return null;
      }
      return decoded['payload'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<List<CropRecommendationResult>?> cachedTop10(String farmId,
      {String? contextHash}) async {
    final cached = await loadCachedTop10(farmId, contextHash: contextHash);
    if (cached == null) return null;
    final top10 = (cached['top10'] as List? ?? const [])
        .map((e) => CropRecommendationResult.fromMap(e as Map<String, dynamic>))
        .toList();
    return top10.isEmpty ? null : top10;
  }

  Future<void> clearTop10Cache(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crop_top10_$farmId');
  }
}
