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
