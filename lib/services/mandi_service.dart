import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// State -> possible districts (fallback map for major states only)
final _stateToDistrictsFallback = {
  'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad'],
  'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Salem', 'Trichy'],
  'Karnataka': ['Bangalore', 'Mysore', 'Hubli', 'Mangalore', 'Belgaum'],
  'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Varanasi', 'Agra', 'Ghaziabad'],
  'Delhi': [
    'Central Delhi',
    'South Delhi',
    'North Delhi',
    'East Delhi',
    'West Delhi'
  ],
  'West Bengal': ['Kolkata', 'Howrah', 'Durgapur', 'Siliguri', 'Bardhaman'],
  'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Jamnagar'],
  'Madhya Pradesh': ['Bhopal', 'Indore', 'Gwalior', 'Jabalpur', 'Kolhapur'],
  'Punjab': ['Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Chandigarh'],
  'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Bikaner'],
  'Haryana': ['Faridabad', 'Gurgaon', 'Ambala', 'Panipat', 'Rohtak'],
  'Andhra Pradesh': [
    'Visakhapatnam',
    'Vijayawada',
    'Tirupati',
    'Guntur',
    'Nellore'
  ],
  'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Khammam', 'Karimnagar'],
};

class MandiPrice {
  final String commodity;
  final String state;
  final String market;
  final double minPrice;
  final double maxPrice;
  final double modalPrice;
  final String unit;
  final String date;
  final String? variety;

  const MandiPrice({
    required this.commodity,
    required this.state,
    required this.market,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    this.unit = 'Rs/Quintal',
    required this.date,
    this.variety,
  });

  factory MandiPrice.fromJson(Map<String, dynamic> json) {
    return MandiPrice(
      commodity: json['commodity'] ?? '',
      state: json['state'] ?? '',
      market: json['market'] ?? json['mandi'] ?? '',
      minPrice: _parseNum(json['min_price']),
      maxPrice: _parseNum(json['max_price']),
      modalPrice: _parseNum(json['modal_price']),
      unit: json['unit'] ?? 'Rs/Quintal',
      date: json['date'] ?? json['arrival_date'] ?? '',
      variety: json['variety'] ?? json['grade'],
    );
  }

  static double _parseNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  String get trend {
    if (modalPrice <= 0 || minPrice <= 0) return 'stable';
    final mid = (minPrice + maxPrice) / 2;
    if (modalPrice > mid * 1.1) return 'up';
    if (modalPrice < mid * 0.9) return 'down';
    return 'stable';
  }

  /// Normalized price per kilogram.
  /// If the unit is quintal (or similar), divides by 100.
  /// Returns a string like "₹X / kg" or the original value with unit if unknown.
  String get pricePerKg {
    final unitLower = unit.toLowerCase();
    if (unitLower.contains('quintal') || unitLower.contains('q')) {
      final kgPrice = modalPrice / 100;
      return '₹${kgPrice.toStringAsFixed(2)} / kg';
    }
    // If unit already per kg, return as-is
    if (unitLower.contains('kg') || unitLower.contains('kilogram')) {
      return '₹${modalPrice.toStringAsFixed(2)} / kg';
    }
    // Unknown unit – return modal price with original unit label
    return '₹${modalPrice.toStringAsFixed(2)} / $unit';
  }
}

class MandiService {
  static const _baseUrl = 'https://mandi-api.onrender.com/v1';
  static const _cacheKey = 'mandi_cache';
  static const _cacheDuration = Duration(hours: 1);

  final Set<String> supportedStates = {
    'Maharashtra',
    'Uttar Pradesh',
    'Punjab',
    'Madhya Pradesh',
    'Karnataka',
  };

  Future<List<MandiPrice>> fetchPrices(
      {String? state, String? commodity}) async {
    if (state == null && commodity == null) {
      return _fetchAllPrices();
    }
    try {
      final params = <String, String>{};
      if (state != null && state.isNotEmpty) params['state'] = state;
      if (commodity != null && commodity.isNotEmpty) {
        params['commodity'] = commodity;
      }
      params['limit'] = '200';
      final uri =
          Uri.parse('$_baseUrl/prices').replace(queryParameters: params);
      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> records = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['prices'] ?? [])
            : [];
        final prices = records.map((r) => MandiPrice.fromJson(r)).toList();
        if (prices.isNotEmpty) await _cachePrices(prices);
        return prices;
      }
      return await _loadCachedPrices();
    } catch (_) {
      return await _loadCachedPrices();
    }
  }

  Future<List<MandiPrice>> _fetchAllPrices() async {
    try {
      final results = await Future.wait(
        supportedStates.map((state) => fetchPrices(state: state)),
      );
      final merged = <MandiPrice>[];
      final seen = <String>{};
      for (final list in results) {
        for (final price in list) {
          final key = '${price.state}|${price.market}|${price.commodity}';
          if (seen.add(key)) merged.add(price);
        }
      }
      if (merged.isNotEmpty) await _cachePrices(merged);
      return merged;
    } catch (_) {
      return await _loadCachedPrices();
    }
  }

  Future<List<MandiPrice>> fetchPricesForState(String state) async {
    return fetchPrices(state: state);
  }

  Future<List<MandiPrice>> fetchPricesForCommodity(String commodity) async {
    return fetchPrices(commodity: commodity);
  }

  Future<List<String>> fetchStates() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/states'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['states'] ?? [])
            : [];
        return List<String>.from(data);
      }
    } catch (_) {}
    return supportedStates.toList();
  }

  /// Fetches district list for a given state from the API.
  /// Derives districts from the aggregator's `/markets` endpoint
  /// (`[{ "market": ..., "district": ... }, ...]`) and falls back to a minimal
  /// static map when the API has no coverage for the state.
  Future<List<String>> fetchDistricts(String state) async {
    try {
      final uri = Uri.parse('$_baseUrl/markets')
          .replace(queryParameters: {'state': state});
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['markets'] ?? [])
            : [];
        final districts = <String>{};
        for (final e in data) {
          if (e is String) {
            final d = e.trim();
            if (d.isNotEmpty) districts.add(d);
          } else if (e is Map) {
            final d = (e['district'] ?? e['name'] ?? '').toString().trim();
            if (d.isNotEmpty) districts.add(d);
          }
        }
        if (districts.isNotEmpty) {
          final list = districts.toList()..sort();
          return list;
        }
      }
    } catch (_) {}
    // Fallback to static map for selected major states
    final fallback = _stateToDistrictsFallback[state];
    if (fallback != null) return fallback;
    // If state not in fallback, return empty list (will show "All Districts")
    return [];
  }

  Future<List<String>> fetchCommodities({String? state}) async {
    try {
      final params = <String, String>{};
      if (state != null && state.isNotEmpty) params['state'] = state;
      final uri = Uri.parse('$_baseUrl/commodities')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['commodities'] ?? [])
            : [];
        return List<String>.from(data);
      }
    } catch (_) {}
    return [];
  }

  Future<List<MandiPrice>> fetchPriceHistory(String state, String commodity,
      {String? from, String? to}) async {
    try {
      final params = <String, String>{'state': state, 'commodity': commodity};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final uri = Uri.parse('$_baseUrl/prices/history')
          .replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['prices'] ?? [])
            : [];
        return List<MandiPrice>.from(data.map((r) => MandiPrice.fromJson(r)));
      }
    } catch (_) {}
    return [];
  }

  Future<void> _cachePrices(List<MandiPrice> prices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prices
          .map((p) => {
                'commodity': p.commodity,
                'state': p.state,
                'market': p.market,
                'min_price': p.minPrice,
                'max_price': p.maxPrice,
                'modal_price': p.modalPrice,
                'unit': p.unit,
                'date': p.date,
                'variety': p.variety,
              })
          .toList();
      await prefs.setString(_cacheKey, json.encode(data));
      await prefs.setString(
          '${_cacheKey}_time', DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<List<MandiPrice>> _loadCachedPrices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString('${_cacheKey}_time');
      if (timeStr == null) return [];
      final cachedTime = DateTime.tryParse(timeStr);
      if (cachedTime == null) return [];
      if (DateTime.now().difference(cachedTime) > _cacheDuration) return [];
      final dataStr = prefs.getString(_cacheKey);
      if (dataStr == null) return [];
      final List<dynamic> decoded = json.decode(dataStr);
      return decoded.map((m) => MandiPrice.fromJson(m)).toList();
    } catch (_) {
      return [];
    }
  }
}
