import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/market_price_models.dart';
import '../data/models/market_selection.dart';
import 'ai/secure_api_client.dart';

/// Secure market-price access for VidhAI.
///
/// The mobile app never calls a market-data provider directly. Every live
/// request goes to the authenticated Render backend, which reads the official
/// AGMARKNET data.gov.in resource. Successful payloads are cached locally for
/// offline display; live failures never fabricate prices.
class MarketPriceService {
  MarketPriceService._();
  static final MarketPriceService instance = MarketPriceService._();

  static const _prefix = 'market_v2_';

  bool _lastOnline = false;
  bool get wasLastCallOnline => _lastOnline;

  static const referenceCommodities = [
    'Tomato',
    'Potato',
    'Onion',
    'Chilli',
    'Brinjal',
    'Cabbage',
    'Cauliflower',
    'Carrot',
    'Beetroot',
    'Bottle Gourd',
    'Bitter Gourd',
    'Ridge Gourd',
    'Banana',
    'Mango',
    'Papaya',
    'Watermelon',
    'Pomegranate',
    'Grapes',
    'Apple',
    'Orange',
    'Coconut',
    'Groundnut',
    'Soybean',
    'Mustard',
    'Sunflower',
    'Sesame',
    'Paddy',
    'Wheat',
    'Maize',
    'Barley',
    'Jowar',
    'Bajra',
    'Ragi',
    'Chickpea',
    'Bengal Gram',
    'Green Gram',
    'Black Gram',
    'Red Gram',
    'Pigeon Pea',
    'Sugarcane',
    'Cotton',
    'Turmeric',
    'Ginger',
    'Garlic',
    'Coriander',
    'Fenugreek',
    'Black Pepper',
    'Cardamom',
    'Coffee',
    'Tea',
    'Rubber',
    'Arecanut',
    'Cashewnut',
  ];

  Future<List<MarketStateInfo>> fetchStates() async {
    try {
      final body = await SecureApiClient.instance.post(
        '/market/states',
        const {},
        debugTag: 'MarketStates',
      );
      final raw = body['states'] as List? ?? const [];
      final states = raw
          .whereType<Map>()
          .map(
            (e) => MarketStateInfo.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
          )
          .where((state) => state.name.trim().isNotEmpty)
          .toList();
      _lastOnline = true;
      await _writeCache(
        'states',
        {'states': states.map((state) => state.toJson()).toList()},
      );
      return states;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] states unavailable: $e');
      final cached = await _readCache('states');
      final raw = cached?['states'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => MarketStateInfo.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
          )
          .toList();
    }
  }

  Future<List<String>> fetchDistricts(String state) async {
    final cleanState = state.trim();
    if (cleanState.isEmpty) return const [];
    final key = 'districts_$cleanState';

    try {
      final body = await SecureApiClient.instance.post(
        '/market/districts',
        {'state': cleanState},
        debugTag: 'MarketDistricts',
      );
      final districts = (body['districts'] as List? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _lastOnline = true;
      await _writeCache(key, {'districts': districts});
      return districts;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] districts unavailable: $e');
      final cached = await _readCache(key);
      return (cached?['districts'] as List?)?.cast<String>() ?? const [];
    }
  }

  Future<List<String>> fetchCommodities({String? state}) async {
    final cleanState = state?.trim() ?? '';
    final key =
        cleanState.isEmpty ? 'commodities' : 'commodities_$cleanState';

    try {
      final body = await SecureApiClient.instance.post(
        '/market/commodities',
        {
          if (cleanState.isNotEmpty) 'state': cleanState,
        },
        debugTag: 'MarketCommodities',
      );
      final live = (body['commodities'] as List? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty);
      final merged = {...live, ...referenceCommodities}.toList()..sort();
      _lastOnline = true;
      await _writeCache(key, {'commodities': merged});
      return merged;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] commodities unavailable: $e');
      final cached = await _readCache(key);
      return (cached?['commodities'] as List?)?.cast<String>() ??
          referenceCommodities;
    }
  }

  Future<MarketPricePayload> fetchPrices({
    String? state,
    String? district,
    String? commodity,
    bool refresh = false,
  }) async {
    final key = queryKey(
      state: state,
      district: district,
      commodity: commodity,
    );

    try {
      final body = await SecureApiClient.instance.post(
        '/market/prices',
        {
          if ((state ?? '').trim().isNotEmpty) 'state': state!.trim(),
          if ((district ?? '').trim().isNotEmpty)
            'district': district!.trim(),
          if ((commodity ?? '').trim().isNotEmpty)
            'commodity': commodity!.trim(),
          'limit': 500,
          'refresh': refresh,
        },
        debugTag: 'MarketPrices',
      );
      final payload = _payloadFromBackend(body);
      _lastOnline = true;
      await _writeCache(key, payload.toJson());
      return payload;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] prices unavailable: $e');
      final cached = await _readCache(key);
      if (cached != null) {
        return MarketPricePayload.fromJson(cached).copyWith(
          fromCache: true,
          stale: true,
        );
      }
      return const MarketPricePayload(prices: [], stale: true);
    }
  }

  Future<MarketPricePayload> fetchSelection(MarketSelection selection, {
    String? commodity, bool refresh = false,
  }) async {
    final queries = selection.queries;
    if (queries.isEmpty) return fetchPrices(commodity: commodity, refresh: refresh);
    final payloads = <MarketPricePayload>[];
    // Three concurrent requests at most; avoid flooding the API on multi-select.
    for (var offset = 0; offset < queries.length; offset += 3) {
      final batch = queries.skip(offset).take(3);
      payloads.addAll(await Future.wait(batch.map((q) => fetchPrices(
        state: q.state, district: q.district, commodity: commodity, refresh: refresh))));
    }
    final prices = mergeMarketRecords(payloads);
    return MarketPricePayload(prices: prices,
      statesWithData: prices.map((p) => p.state).toSet().toList(),
      commodities: prices.map((p) => p.commodity).toSet().toList(),
      totalPriceRecords: prices.length,
      pricePerKgAvailable: prices.where((p) => p.hasReliablePerKg).length,
      latestDate: prices.isEmpty ? null : prices.first.date,
      stale: payloads.any((p) => p.stale),
      fromCache: payloads.any((p) => p.fromCache),
      source: payloads.map((p) => p.source).where((s) => s.isNotEmpty).toSet().join(', '),
      fetchedAt: payloads.map((p) => p.fetchedAt).where((s) => s.isNotEmpty).fold<String>('', (a, b) => a.isEmpty || b.compareTo(a) < 0 ? b : a),
    );
  }

  Future<MarketPricePayload> fetchSummary({
    String? state,
    String? commodity,
    bool refresh = false,
  }) {
    return fetchPrices(
      state: state,
      commodity: commodity,
      refresh: refresh,
    );
  }

  Future<String?> fetchInsight({
    String? state,
    String? district,
    String? commodity,
    required String language,
    String farmContext = '',
  }) async {
    try {
      final body = await SecureApiClient.instance.post(
        '/market/insight',
        {
          if ((state ?? '').trim().isNotEmpty) 'state': state!.trim(),
          if ((district ?? '').trim().isNotEmpty)
            'district': district!.trim(),
          if ((commodity ?? '').trim().isNotEmpty)
            'commodity': commodity!.trim(),
          'language': language,
          if (farmContext.trim().isNotEmpty) 'farmContext': farmContext.trim(),
        },
        debugTag: 'MarketInsight',
      );
      return body['insight']?.toString();
    } catch (e) {
      debugPrint('[MarketPriceService] insight unavailable: $e');
      return null;
    }
  }

  Future<List<PriceHistoryPoint>> fetchHistory({
    required String state,
    required String commodity,
    int days = 30,
  }) async {
    final cleanState = state.trim();
    final cleanCommodity = commodity.trim();
    if (cleanState.isEmpty || cleanCommodity.isEmpty) return const [];

    final key = 'history_${cleanState}_$cleanCommodity';
    try {
      final body = await SecureApiClient.instance.post(
        '/market/history',
        {
          'state': cleanState,
          'commodity': cleanCommodity,
          'days': days,
        },
        debugTag: 'MarketHistory',
      );
      final points = (body['history'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (e) => PriceHistoryPoint.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      _lastOnline = true;
      if (points.isNotEmpty) {
        await _writeCache(
          key,
          {'history': points.map((point) => point.toJson()).toList()},
        );
      }
      return points;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] history unavailable: $e');
      final cached = await _readCache(key);
      final raw = cached?['history'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => PriceHistoryPoint.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>()),
            ),
          )
          .where((point) {
            if (days >= 30) return true;
            final date = DateTime.tryParse(point.date);
            return date != null &&
                DateTime.now().difference(date).inDays <= days;
          })
          .toList();
    }
  }

  Future<List<MarketPriceRecord>> cachedPrices({
    String? state,
    String? district,
    String? commodity,
  }) async {
    final results = <MarketPriceRecord>[];
    final exact = await _readCache(
      queryKey(
        state: state,
        district: district,
        commodity: commodity,
      ),
    );
    if (exact != null) {
      results.addAll(_recordsFromCache(exact));
    }

    if (results.isEmpty && (state ?? '').trim().isNotEmpty) {
      final stateOnly = await _readCache(queryKey(state: state));
      if (stateOnly != null) {
        results.addAll(_recordsFromCache(stateOnly));
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> cachedMarketContext(
    String state, {
    String? district,
  }) async {
    final records = await cachedPrices(
      state: state,
      district: district,
    );
    final seen = <String>{};
    final output = <Map<String, dynamic>>[];

    for (final record in records) {
      if (!seen.add(record.commodity.toLowerCase())) continue;
      output.add({
        'commodity': record.commodity,
        'market': record.market,
        'district': record.district,
        'state': record.state,
        'normalizedPricePerKg': record.normalizedPricePerKg,
        'date': record.date,
        'source': record.source,
      });
      if (output.length >= 8) break;
    }
    return output;
  }

  MarketPricePayload _payloadFromBackend(Map<String, dynamic> body) {
    final records = (body['prices'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (e) => MarketPriceRecord.fromJson(
            Map<String, dynamic>.from(e.cast<String, dynamic>()),
          ),
        )
        .toList();

    final latestDates = records
        .map((record) => record.date)
        .where((date) => date.isNotEmpty)
        .toList()
      ..sort();

    final states = records
        .map((record) => record.state)
        .where((state) => state.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final commodities =
        records.map((record) => record.commodity).toSet().toList()..sort();

    return MarketPricePayload(
      prices: records,
      statesWithData: states,
      commodities: commodities,
      latestDate: latestDates.isNotEmpty ? latestDates.last : null,
      totalPriceRecords: records.length,
      pricePerKgAvailable:
          records.where((record) => record.hasReliablePerKg).length,
      fromCache: body['fromCache'] == true,
      stale: body['stale'] == true,
      source: body['source']?.toString() ?? 'AGMARKNET (data.gov.in)',
      fetchedAt:
          body['fetchedAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  static String queryKey({
    String? state,
    String? district,
    String? commodity,
  }) {
    final parts = <String>['prices'];
    if ((state ?? '').trim().isNotEmpty) {
      parts.add('st_${state!.trim()}');
    }
    if ((district ?? '').trim().isNotEmpty) {
      parts.add('d_${district!.trim()}');
    }
    if ((commodity ?? '').trim().isNotEmpty) {
      parts.add('c_${commodity!.trim()}');
    }
    return parts.join('~');
  }

  List<MarketPriceRecord> _recordsFromCache(Map<String, dynamic> cached) {
    final raw = cached['prices'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => MarketPriceRecord.fromJson(
            Map<String, dynamic>.from(e.cast<String, dynamic>()),
          ),
        )
        .toList();
  }

  Future<void> _writeCache(
    String key,
    Map<String, dynamic> data,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(data));
    } catch (e) {
      debugPrint('[MarketPriceService] cache write failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}

extension MarketPricePayloadX on MarketPricePayload {
  MarketPricePayload copyWith({
    List<MarketPriceRecord>? prices,
    bool? fromCache,
    bool? stale,
    String? fetchedAt,
  }) =>
      MarketPricePayload(
        prices: prices ?? this.prices,
        statesWithData: statesWithData,
        commodities: commodities,
        latestDate: latestDate,
        totalPriceRecords: totalPriceRecords,
        pricePerKgAvailable: pricePerKgAvailable,
        fromCache: fromCache ?? this.fromCache,
        stale: stale ?? this.stale,
        source: source,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
}
