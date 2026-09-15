import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/market_price_models.dart';
import 'ai/secure_api_client.dart';

/// Market-price access.
///
/// Prices come from the public AGMARKNET/data.gov.in aggregator
/// (`mandi-api.onrender.com`) directly from the device — the same approved
/// provider the Firebase backend wraps. No key is needed on the client, and
/// prices always carry their source, date, market and original unit; ₹/kg is
/// only highlighted when the weight conversion is reliable.
///
/// Offline-first: every successful response is mirrored into a per-query
/// SharedPreferences cache. When the source is unreachable the cached payload
/// is returned flagged `stale` so the UI can show the offline banner while
/// still keeping prices, source and date visible.
class MarketPriceService {
  MarketPriceService._();
  static final MarketPriceService instance = MarketPriceService._();

  static const _mandiBase = 'https://mandi-api.onrender.com/v1';
  static const _timeout = Duration(seconds: 45);
  static const _prefix = 'market_v1_';

  bool _lastOnline = false;
  bool get wasLastCallOnline => _lastOnline;

  /// States the AGMARKNET aggregator actually serves; other states 404.
  static const providerStates = [
    'Maharashtra',
    'Uttar Pradesh',
    'Punjab',
    'Madhya Pradesh',
    'Karnataka',
  ];

  /// Authoritative commodity reference merged with the aggregator's list so
  /// the picker stays usable even when the API caps its page.
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

  // Province district lists (authoritative administrative reference) used to
  // derive the district for a reported market within the covered states.
  static const Map<String, List<String>> _geoDistricts = {
    'maharashtra': [
      'Ahmadnagar',
      'Akola',
      'Amravati',
      'Aurangabad',
      'Beed',
      'Bhandara',
      'Buldhana',
      'Chandrapur',
      'Chhatrapati Sambhajinagar',
      'Dhule',
      'Gadchiroli',
      'Gondia',
      'Hingoli',
      'Jalgaon',
      'Jalna',
      'Kolhapur',
      'Latur',
      'Mumbai City',
      'Mumbai Suburban',
      'Nagpur',
      'Nanded',
      'Nandurbar',
      'Nashik',
      'Osmanabad',
      'Palghar',
      'Parbhani',
      'Pune',
      'Raigad',
      'Ratnagiri',
      'Sangli',
      'Satara',
      'Sindhudurg',
      'Solapur',
      'Thane',
      'Wardha',
      'Washim',
      'Yavatmal',
    ],
    'uttar pradesh': [
      'Agra',
      'Aligarh',
      'Ambedkar Nagar',
      'Amethi',
      'Amroha',
      'Auraiya',
      'Ayodhya',
      'Azamgarh',
      'Baghpat',
      'Bahraich',
      'Ballia',
      'Balrampur',
      'Banda',
      'Barabanki',
      'Bareilly',
      'Basti',
      'Bhadohi',
      'Bijnor',
      'Budaun',
      'Bulandshahr',
      'Chandauli',
      'Chitrakoot',
      'Deoria',
      'Etah',
      'Etawah',
      'Farrukhabad',
      'Fatehpur',
      'Firozabad',
      'Gautam Buddha Nagar',
      'Ghaziabad',
      'Ghazipur',
      'Gonda',
      'Gorakhpur',
      'Hamirpur',
      'Hapur',
      'Hardoi',
      'Hathras',
      'Jalaun',
      'Jaunpur',
      'Jhansi',
      'Kannauj',
      'Kanpur Dehat',
      'Kanpur Nagar',
      'Kasganj',
      'Kaushambi',
      'Kushinagar',
      'Lakhimpur Kheri',
      'Lalitpur',
      'Lucknow',
      'Maharajganj',
      'Mahoba',
      'Mainpuri',
      'Mathura',
      'Mau',
      'Meerut',
      'Mirzapur',
      'Moradabad',
      'Muzaffarnagar',
      'Pilibhit',
      'Pratapgarh',
      'Prayagraj',
      'Raebareli',
      'Rampur',
      'Saharanpur',
      'Sambhal',
      'Sant Kabir Nagar',
      'Shahjahanpur',
      'Shamli',
      'Shravasti',
      'Siddharthnagar',
      'Sitapur',
      'Sonbhadra',
      'Sultanpur',
      'Unnao',
      'Varanasi',
    ],
    'punjab': [
      'Amritsar',
      'Barnala',
      'Bathinda',
      'Faridkot',
      'Fatehgarh Sahib',
      'Fazilka',
      'Firozpur',
      'Gurdaspur',
      'Hoshiarpur',
      'Jalandhar',
      'Kapurthala',
      'Ludhiana',
      'Mansa',
      'Moga',
      'Muktsar',
      'Pathankot',
      'Patiala',
      'Rupnagar',
      'Sahibzada Ajit Singh Nagar',
      'Sangrur',
      'Shahid Bhagat Singh Nagar',
      'Tarn Taran',
    ],
    'madhya pradesh': [
      'Agar Malwa',
      'Alirajpur',
      'Anuppur',
      'Ashoknagar',
      'Balaghat',
      'Barwani',
      'Betul',
      'Bhind',
      'Bhopal',
      'Burhanpur',
      'Chhatarpur',
      'Chhindwara',
      'Damoh',
      'Datia',
      'Dewas',
      'Dhar',
      'Dindori',
      'Guna',
      'Gwalior',
      'Harda',
      'Hoshangabad',
      'Indore',
      'Jabalpur',
      'Jhabua',
      'Katni',
      'Khandwa',
      'Khargone',
      'Mandla',
      'Mandsaur',
      'Morena',
      'Narmadapuram',
      'Narsinghpur',
      'Neemuch',
      'Niwari',
      'Panna',
      'Raisen',
      'Rajgarh',
      'Ratlam',
      'Rewa',
      'Sagar',
      'Satna',
      'Sehore',
      'Seoni',
      'Shahdol',
      'Shajapur',
      'Sheopur',
      'Shivpuri',
      'Sidhi',
      'Singrauli',
      'Tikamgarh',
      'Ujjain',
      'Umaria',
      'Vidisha',
    ],
    'karnataka': [
      'Bagalkot',
      'Ballari',
      'Belagavi',
      'Bengaluru Rural',
      'Bengaluru Urban',
      'Bidar',
      'Chamarajanagar',
      'Chikkaballapur',
      'Chikkamagaluru',
      'Chitradurga',
      'Dakshina Kannada',
      'Davanagere',
      'Dharwad',
      'Gadag',
      'Hassan',
      'Haveri',
      'Kalaburagi',
      'Kodagu',
      'Kolar',
      'Koppal',
      'Mandya',
      'Mysuru',
      'Raichur',
      'Ramanagara',
      'Shivamogga',
      'Tumakuru',
      'Udupi',
      'Uttara Kannada',
      'Vijayapura',
      'Yadgir',
    ],
  };

  // ── HTTP helpers ───────────────────────────────────────────────────────────

  Future<dynamic> _getJson(
    String path, {
    Map<String, String> params = const {},
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$_mandiBase$path').replace(
        queryParameters:
            params.isEmpty ? null : params.map((k, v) => MapEntry(k, v)));
    final res = await http.get(uri, headers: const {
      'Accept': 'application/json'
    }).timeout(timeout ?? _timeout);
    if (res.statusCode != 200) {
      throw SecureApiException(
        'Mandi provider failed (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  List<dynamic> _rows(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map) {
      for (final k in ['data', 'prices', 'records', 'response', 'results']) {
        final v = payload[k];
        if (v is List) return v;
      }
    }
    return const [];
  }

  double? _parseNum(Object? v) {
    if (v == null || v == '') return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp('[₹,]'), ''));
    return null;
  }

  double _round2(double v) => (v * 100).roundToDouble() / 100;

  String _normalize(Object? name) {
    final s = (name ?? '').toString().trim().toLowerCase();
    return s
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ── Unit -> kg conversion (mirror of the backend reference) ────────────────

  double? _unitFactor(String? rawUnit) {
    final u = (rawUnit ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[./]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (u.isEmpty) return null;
    if (u.contains('quintal') || u.contains('qtl') || u.contains('100 kg')) {
      return 100;
    }
    if (u.contains('ton')) return 1000;
    if (u.contains('kg') || u.contains('kilogram')) {
      final m = RegExp(r'(\d+)\s*kg').firstMatch(u);
      if (m != null) return double.tryParse(m.group(1)!);
      return 1;
    }
    if (u.contains('gram')) {
      final m = RegExp(r'(\d+)\s*gram').firstMatch(u);
      if (m != null) {
        final n = double.tryParse(m.group(1)!);
        if (n != null) return n / 1000;
      }
      return 0.001;
    }
    return null;
  }

  String _unitLabel(String? rawUnit) {
    final u = (rawUnit ?? '').toLowerCase();
    if (u.contains('quintal') || u.contains('qtl')) return 'Quintal';
    if (u.contains('ton')) return 'Tonne';
    if (u.contains('100')) return '100 kg';
    if (u.contains('kg') || u.contains('kilogram')) {
      final m = RegExp(r'(\d+)\s*kg').firstMatch(u);
      return m != null ? '${m.group(1)} kg' : 'kg';
    }
    if (u.contains('gram')) {
      final m = RegExp(r'(\d+)\s*gram').firstMatch(u);
      return m != null ? '${m.group(1)} g' : 'g';
    }
    final tokens = (rawUnit ?? '')
        .replaceAll(RegExp('[₹]'), '')
        .replaceAll(RegExp(r'rs\.?', caseSensitive: false), '')
        .replaceAll(RegExp(r'[/.]'), ' ')
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) =>
            t.isNotEmpty &&
            !const ['per', 'of', 'the', 'a', 'an'].contains(t.toLowerCase()))
        .toList();
    if (tokens.isEmpty) return 'Unknown';
    return tokens
        .map((t) => t[0].toUpperCase() + t.substring(1).toLowerCase())
        .join(' ');
  }

  /// Best-effort market name -> district using the authoritative reference.
  String _districtOf(String state, String market) {
    final marketName = market.trim();
    if (marketName.isEmpty) return '';
    final districts = _geoDistricts[_normalize(state)] ?? const <String>[];
    if (districts.isEmpty) return '';
    var m = marketName.toLowerCase().trim();
    m = m.replaceAll(
      RegExp(
          r'\b(apmc|mandi|market|yard|bazaar|agricultural|produce|regulate\d*|committee)\b'),
      ' ',
    );
    m = m.replaceAll(RegExp(r'\s+'), ' ').trim();
    final tokens = m.split(' ').where((t) => t.isNotEmpty).toList();
    var best = '';
    for (final d in districts) {
      final dl = d.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final matches = m == dl ||
          m.startsWith('$dl ') ||
          dl.startsWith('$m ') ||
          (tokens.length == 1 && dl.split(' ').contains(tokens[0]));
      if (matches && dl.length > best.length) best = d;
    }
    return best;
  }

  MarketPriceRecord? _mapRecord(Map<String, dynamic> row) {
    final commodity =
        (row['commodity'] ?? row['commodity_name'] ?? row['name'] ?? '')
            .toString()
            .trim();
    if (commodity.isEmpty) return null;
    final modal =
        _parseNum(row['modal_price']) ?? _parseNum(row['model_price']);
    final minPrice = _parseNum(row['min_price']);
    final maxPrice = _parseNum(row['max_price']);
    final originalUnit =
        (row['unit'] ?? row['price_unit'] ?? 'Rs/Quintal').toString().trim();
    final conversionFactor = _unitFactor(originalUnit);
    final state = (row['state'] ?? '').toString().trim();
    final market = (row['market'] ?? row['mandi'] ?? '').toString().trim();
    final rowDistrict = (row['district'] ?? '').toString().trim();
    return MarketPriceRecord(
      commodity: commodity,
      variety: row['variety']?.toString() ?? row['grade']?.toString(),
      state: state,
      district:
          rowDistrict.isNotEmpty ? rowDistrict : _districtOf(state, market),
      market: market,
      minPrice: minPrice,
      modalPrice: modal,
      maxPrice: maxPrice,
      originalUnit: originalUnit,
      unitLabel: _unitLabel(originalUnit),
      conversionFactor: conversionFactor,
      normalizedPricePerKg: (conversionFactor != null && modal != null)
          ? _round2(modal / conversionFactor)
          : null,
      arrival: row['arrival']?.toString(),
      date: (row['date'] ?? row['arrival_date'] ?? row['price_date'] ?? '')
          .toString()
          .trim(),
      source: 'AGMARKNET (data.gov.in)',
    );
  }

  // ── Public API (mirrors the previous back-end surface) ────────────────────

  Future<List<MarketStateInfo>> fetchStates() async {
    try {
      final body = await SecureApiClient.instance.post('/market/states', {});
      final raw = body['states'] as List? ?? const [];
      final states = raw
          .whereType<Map>()
          .map((e) => MarketStateInfo.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>())))
          .where((s) => s.name.isNotEmpty)
          .toList();
      if (states.isEmpty) throw const SecureApiException('No states.');
      _lastOnline = true;
      await _writeCache('states', {
        'states': states.map((s) => s.toJson()).toList(),
      });
      return states;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] states failed (offline fallback): $e');
      final cached = await _readCache('states');
      if (cached != null) {
        return (cached['states'] as List? ?? const [])
            .map((e) => MarketStateInfo.fromJson(
                Map<String, dynamic>.from((e as Map).cast<String, dynamic>())))
            .toList();
      }
      return const [];
    }
  }

  Future<List<String>> fetchDistricts(String state) async {
    if (state.trim().isEmpty) return const [];
    final key = 'districts_$state';
    try {
      final body = await SecureApiClient.instance.post(
        '/market/districts',
        {'state': state},
      );
      final districts = (body['districts'] as List? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _lastOnline = true;
      await _writeCache(key, {'districts': districts});
      return districts;
    } catch (e) {
      _lastOnline = false;
      debugPrint(
          '[MarketPriceService] districts failed (offline fallback): $e');
      final cached = await _readCache(key);
      return (cached?['districts'] as List?)?.cast<String>() ?? const [];
    }
  }

  Future<List<String>> fetchCommodities({String? state}) async {
    final key =
        state == null || state.isEmpty ? 'commodities' : 'commodities_$state';
    try {
      final body = await SecureApiClient.instance.post('/market/commodities', {
        if (state != null && state.isNotEmpty) 'state': state,
      });
      final fromApi = (body['commodities'] as List? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      _lastOnline = true;
      final merged = {
        ...fromApi,
        ...referenceCommodities,
      }.toList();
      await _writeCache(key, {'commodities': merged});
      return merged;
    } catch (e) {
      _lastOnline = false;
      debugPrint(
          '[MarketPriceService] commodities failed (offline fallback): $e');
      final cached = await _readCache(key);
      return (cached?['commodities'] as List?)?.cast<String>() ??
          referenceCommodities;
    }
  }

  List<String> _mergeCommodities(List<String> api) => {
        ...api,
        ...referenceCommodities,
      }.toList();

  Future<MarketPricePayload> fetchPrices({
    String? state,
    String? district,
    String? commodity,
    bool refresh = false,
  }) async {
    final key =
        queryKey(state: state, district: district, commodity: commodity);
    try {
      final body = await SecureApiClient.instance.post('/market/prices', {
        if (state != null && state.isNotEmpty) 'state': state,
        if (district != null && district.isNotEmpty) 'district': district,
        if (commodity != null && commodity.isNotEmpty) 'commodity': commodity,
        'limit': 500,
        'refresh': refresh,
      });
      final records = (body['prices'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => MarketPriceRecord.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>())))
          .toList();
      _lastOnline = true;
      final payload = _buildPayload(records).copyWith(
        fromCache: body['fromCache'] == true,
        stale: body['stale'] == true,
        fetchedAt: body['fetchedAt']?.toString(),
      );
      await _writeCache(key, payload.toJson());
      return payload;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] prices failed (offline fallback): $e');
      final cached = await _readCache(key);
      if (cached != null) {
        return MarketPricePayload.fromJson(cached).copyWith(
          fromCache: true,
          stale: true,
        );
      }
      return const MarketPricePayload(prices: []);
    }
  }

  Future<MarketPricePayload> fetchSummary({
    String? state,
    String? commodity,
  }) async {
    final key = 'summary_${state ?? 'in'}_${commodity ?? 'all'}';
    try {
      final body = await SecureApiClient.instance.post('/market/prices', {
        if (state != null && state.isNotEmpty) 'state': state,
        if (commodity != null && commodity.isNotEmpty) 'commodity': commodity,
        'limit': 500,
      });
      final records = (body['prices'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => MarketPriceRecord.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>())))
          .toList();
      _lastOnline = true;
      final payload = _buildPayload(records).copyWith(
        fromCache: body['fromCache'] == true,
        stale: body['stale'] == true,
        fetchedAt: body['fetchedAt']?.toString(),
      );
      await _writeCache(key, payload.toJson());
      return payload;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] summary failed (offline fallback): $e');
      final cached = await _readCache(key);
      if (cached != null) {
        return MarketPricePayload.fromJson(cached).copyWith(
          fromCache: true,
          stale: true,
        );
      }
      return const MarketPricePayload(prices: []);
    }
  }

  Future<List<MarketPriceRecord>> _fetchRecords({
    String? state,
    String? district,
    String? commodity,
  }) async {
    final st = (state ?? '').trim();
    final cm = (commodity ?? '').trim();
    final supported = st.isEmpty ||
        providerStates.any((s) => s.toLowerCase() == st.toLowerCase());

    List<Map<String, dynamic>> rows;
    if (supported) {
      final params = <String, String>{};
      if (st.isNotEmpty) params['state'] = st;
      if (cm.isNotEmpty) params['commodity'] = cm;
      params['limit'] = '500';
      final payload = await _getJson('/prices', params: params);
      rows = _rows(payload)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      // Not a provider state -> no reported series (honest empty, never fake).
      return const [];
    }

    final records =
        rows.map(_mapRecord).whereType<MarketPriceRecord>().toList();
    records.sort((a, b) => (b.date).compareTo(a.date));
    var out = records.take(300).toList();
    if (district != null && district.trim().isNotEmpty) {
      final dq = district.trim().toLowerCase();
      out = out.where((r) => r.district.toLowerCase().contains(dq)).toList();
    }
    return out;
  }

  Future<List<MarketPriceRecord>> _fetchSummaryRecords({
    String? state,
    String? commodity,
  }) async {
    final st = (state ?? '').trim();
    final cm = (commodity ?? '').trim();
    if (st.isNotEmpty) return _fetchRecords(state: st, commodity: cm);
    // Overview: provider rejects a bare query, so fan out the covered states
    // and merge (same strategy as the backend).
    final results = await Future.wait(providerStates.map((s) async {
      try {
        return await _fetchRecords(state: s, commodity: cm);
      } catch (_) {
        return const <MarketPriceRecord>[];
      }
    }));
    final merged = <MarketPriceRecord>[];
    for (final r in results) {
      merged.addAll(r);
    }
    merged.sort((a, b) => b.date.compareTo(a.date));
    return merged.take(400).toList();
  }

  MarketPricePayload _buildPayload(List<MarketPriceRecord> records) {
    final latestDate =
        records.map((r) => r.date).where((d) => d.isNotEmpty).toList()..sort();
    final statesWithData = records
        .map((r) => r.state)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final commodities = records.map((r) => r.commodity).toSet().toList()
      ..sort();
    final perKg = records.where((r) => r.hasReliablePerKg).length;
    return MarketPricePayload(
      prices: records,
      statesWithData: statesWithData,
      commodities: commodities,
      latestDate: latestDate.isNotEmpty ? latestDate.last : null,
      totalPriceRecords: records.length,
      pricePerKgAvailable: perKg,
      source: 'AGMARKNET (data.gov.in)',
      fetchedAt: DateTime.now().toIso8601String(),
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
      final body = await SecureApiClient.instance.post('/market/insight', {
        if (state != null && state.isNotEmpty) 'state': state,
        if (district != null && district.isNotEmpty) 'district': district,
        if (commodity != null && commodity.isNotEmpty) 'commodity': commodity,
        'language': language,
        if (farmContext.isNotEmpty) 'farmContext': farmContext,
      }).timeout(const Duration(seconds: 12));
      return body['insight'] as String?;
    } catch (e) {
      debugPrint('[MarketPriceService] insight unavailable (no backend): $e');
      return null;
    }
  }

  Future<List<PriceHistoryPoint>> fetchHistory({
    required String state,
    required String commodity,
    int days = 30,
  }) async {
    final key = 'history_${state}_$commodity';
    try {
      final body = await SecureApiClient.instance.post('/market/history', {
        'state': state,
        'commodity': commodity,
        'days': days,
      });
      _lastOnline = true;
      final points = (body['history'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PriceHistoryPoint.fromJson(
              Map<String, dynamic>.from(e.cast<String, dynamic>())))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (points.isNotEmpty) {
        await _writeCache(
            key, {'history': points.map((p) => p.toJson()).toList()});
      }
      return points;
    } catch (e) {
      _lastOnline = false;
      debugPrint('[MarketPriceService] history failed (offline fallback): $e');
      final cached = await _readCache(key);
      final raw = cached?['history'];
      if (raw is List) {
        return raw
            .map((j) => PriceHistoryPoint.fromJson(
                Map<String, dynamic>.from((j as Map).cast<String, dynamic>())))
            .toList()
            .where((p) {
          if (days >= 30) return true;
          final d = DateTime.tryParse(p.date);
          return d != null && DateTime.now().difference(d).inDays <= days;
        }).toList();
      }
      return const [];
    }
  }

  // ── cache ──────────────────────────────────────────────────────────────────

  /// Cache-only prices for a query; tries the exact key then the state
  /// overview cache (offline-safe — no network).
  Future<List<MarketPriceRecord>> cachedPrices({
    String? state,
    String? district,
    String? commodity,
  }) async {
    final results = <MarketPriceRecord>[];
    final exact = await _readCache(
        queryKey(state: state, district: district, commodity: commodity));
    if (exact != null) results.addAll(_recordsFromCache(exact));
    if (results.isEmpty && state != null && state.isNotEmpty) {
      final summary = await _readCache('summary_${state}_all');
      if (summary != null) results.addAll(_recordsFromCache(summary));
    }
    return results;
  }

  /// Cache-only market context as plain maps for the recommendation prompt
  /// (state, district and matched records — offline-safe).
  Future<List<Map<String, dynamic>>> cachedMarketContext(
    String state, {
    String? district,
  }) async {
    final records = await cachedPrices(state: state, district: district);
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final r in records) {
      if (seen.add(r.commodity.toLowerCase())) {
        out.add({
          'commodity': r.commodity,
          'market': r.market,
          'district': r.district,
          'state': r.state,
        });
      }
      if (out.length >= 8) break;
    }
    return out;
  }

  List<MarketPriceRecord> _recordsFromCache(Map<String, dynamic> cached) {
    final raw = cached['prices'];
    if (raw is! List) return const [];
    return raw
        .map((j) => MarketPriceRecord.fromJson(
            Map<String, dynamic>.from((j as Map).cast<String, dynamic>())))
        .toList();
  }

  static String queryKey({String? state, String? district, String? commodity}) {
    final parts = <String>['prices'];
    if (state != null && state.isNotEmpty) parts.add('st_$state');
    if (district != null && district.isNotEmpty) parts.add('d_$district');
    if (commodity != null && commodity.isNotEmpty) parts.add('c_$commodity');
    return parts.join('~');
  }

  Future<void> _writeCache(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', json.encode(data));
    } catch (e) {
      debugPrint('[MarketPriceService] cache write failed: $e');
    }
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
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
