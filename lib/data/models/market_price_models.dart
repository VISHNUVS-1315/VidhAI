/// Market-price data models mirroring the backend `/market/*` responses.
///
/// Prices are always reported together with their original unit and an
/// optional conversion factor, so `normalizedPricePerKg` is only treated as
/// reliable when the conversion factor is known. Where it is not known the UI
/// shows "Price unit unavailable" instead of fabricating a per-kg value.
class MarketStateInfo {
  final String id;
  final String name;
  final bool ut;
  final int districtCount;

  const MarketStateInfo({
    required this.id,
    required this.name,
    required this.ut,
    this.districtCount = 0,
  });

  factory MarketStateInfo.fromJson(Map<String, dynamic> json) =>
      MarketStateInfo(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        ut: json['ut'] ?? false,
        districtCount: (json['districtCount'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'ut': ut, 'districtCount': districtCount};
}

class MarketPriceRecord {
  final String commodity;
  final String? variety;
  final String state;
  final String district;
  final String market;
  final double? minPrice;
  final double? modalPrice;
  final double? maxPrice;
  final String originalUnit;
  final String unitLabel;
  final double? conversionFactor;
  final double? normalizedPricePerKg;
  final String? arrival;
  final String date;
  final String source;

  const MarketPriceRecord({
    required this.commodity,
    this.variety,
    required this.state,
    required this.district,
    required this.market,
    this.minPrice,
    this.modalPrice,
    this.maxPrice,
    this.originalUnit = 'Quintal',
    this.unitLabel = 'Quintal',
    this.conversionFactor,
    this.normalizedPricePerKg,
    this.arrival,
    this.date = '',
    this.source = '',
  });

  factory MarketPriceRecord.fromJson(Map<String, dynamic> json) {
    double? v(dynamic x) => x is num
        ? x.toDouble()
        : x is String
            ? double.tryParse(x)
            : null;
    return MarketPriceRecord(
      commodity: json['commodity'] ?? '',
      variety: json['variety'] as String?,
      state: json['state'] ?? '',
      district: json['district'] ?? '',
      market: json['market'] ?? '',
      minPrice: v(json['minPrice']),
      modalPrice: v(json['modalPrice']),
      maxPrice: v(json['maxPrice']),
      originalUnit: json['originalUnit'] ?? '',
      unitLabel: json['unitLabel'] ?? '',
      conversionFactor: v(json['conversionFactor']),
      normalizedPricePerKg: v(json['normalizedPricePerKg']),
      arrival: json['arrival'] as String?,
      date: json['date'] ?? '',
      source: json['source'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'commodity': commodity,
        'variety': variety,
        'state': state,
        'district': district,
        'market': market,
        'minPrice': minPrice,
        'modalPrice': modalPrice,
        'maxPrice': maxPrice,
        'originalUnit': originalUnit,
        'unitLabel': unitLabel,
        'conversionFactor': conversionFactor,
        'normalizedPricePerKg': normalizedPricePerKg,
        'arrival': arrival,
        'date': date,
        'source': source,
      };

  bool get hasReliablePerKg =>
      conversionFactor != null && normalizedPricePerKg != null;

  /// Trend based on modal-vs-range like the previous UI, using only reported figures.
  String get trend {
    if (modalPrice == null ||
        modalPrice! <= 0 ||
        minPrice == null ||
        maxPrice == null) {
      return 'stable';
    }
    final mid = (minPrice! + maxPrice!) / 2;
    if (modalPrice! > mid * 1.1) return 'up';
    if (modalPrice! < mid * 0.9) return 'down';
    return 'stable';
  }

  /// Accumulates into the backend FarmContext.market array (actual data only).
  Map<String, dynamic> toCropMarketContext() => {
        'commodity': commodity,
        'normalizedPricePerKg': normalizedPricePerKg,
        'state': state,
        'date': date,
        'source': source,
      };
}

/// Payload of a `/market/prices` or `/market/summary` response.
class MarketPricePayload {
  final List<MarketPriceRecord> prices;
  final List<String> statesWithData;
  final List<String> commodities;
  final String? latestDate;
  final int totalPriceRecords;
  final int pricePerKgAvailable;
  final bool fromCache;
  final bool stale;
  final String source;
  final String fetchedAt;

  const MarketPricePayload({
    required this.prices,
    this.statesWithData = const [],
    this.commodities = const [],
    this.latestDate,
    this.totalPriceRecords = 0,
    this.pricePerKgAvailable = 0,
    this.fromCache = false,
    this.stale = false,
    this.source = '',
    this.fetchedAt = '',
  });

  factory MarketPricePayload.fromJson(Map<String, dynamic> json) {
    final rawPrices = json['prices'];
    return MarketPricePayload(
      prices: rawPrices is List
          ? rawPrices
              .map((j) => MarketPriceRecord.fromJson(Map<String, dynamic>.from(
                  (j as Map).cast<String, dynamic>())))
              .toList()
          : const [],
      statesWithData:
          (json['statesWithData'] as List?)?.cast<String>() ?? const [],
      commodities: (json['commodities'] as List?)?.cast<String>() ?? const [],
      latestDate: json['latestDate'] as String?,
      totalPriceRecords: (json['totalPriceRecords'] as num?)?.toInt() ?? 0,
      pricePerKgAvailable: (json['pricePerKgAvailable'] as num?)?.toInt() ?? 0,
      fromCache: json['fromCache'] ?? false,
      stale: json['stale'] ?? false,
      source: json['source'] ?? '',
      fetchedAt: json['fetchedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'prices': prices.map((p) => p.toJson()).toList(),
        'statesWithData': statesWithData,
        'commodities': commodities,
        'latestDate': latestDate,
        'totalPriceRecords': totalPriceRecords,
        'pricePerKgAvailable': pricePerKgAvailable,
        'fromCache': fromCache,
        'stale': stale,
        'source': source,
        'fetchedAt': fetchedAt,
      };
}

/// One reported daily average (AGMARKNET) used for the 7/30-day trend.
class PriceHistoryPoint {
  final String date;
  final double modalPriceReported;
  final double minPriceReported;
  final double maxPriceReported;
  final int dataPoints;
  final double conversionFactor;
  final double normalizedPricePerKg;

  const PriceHistoryPoint({
    required this.date,
    required this.modalPriceReported,
    required this.minPriceReported,
    required this.maxPriceReported,
    required this.dataPoints,
    required this.conversionFactor,
    required this.normalizedPricePerKg,
  });

  factory PriceHistoryPoint.fromJson(Map<String, dynamic> json) {
    double v(Object? x) => x is num
        ? x.toDouble()
        : x is String
            ? double.tryParse(x) ?? 0
            : 0;
    return PriceHistoryPoint(
      date: json['date'] ?? '',
      modalPriceReported: v(json['modalPriceReported']),
      minPriceReported: v(json['minPriceReported']),
      maxPriceReported: v(json['maxPriceReported']),
      dataPoints: (json['dataPoints'] as num?)?.toInt() ?? 0,
      conversionFactor:
          v(json['conversionFactor']) == 0 ? 1 : v(json['conversionFactor']),
      normalizedPricePerKg: v(json['normalizedPricePerKg']),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'modalPriceReported': modalPriceReported,
        'minPriceReported': minPriceReported,
        'maxPriceReported': maxPriceReported,
        'dataPoints': dataPoints,
        'conversionFactor': conversionFactor,
        'normalizedPricePerKg': normalizedPricePerKg,
      };
}

/// Compact display helpers (no currency assumptions beyond INR).
class MarketFormat {
  static String inr(double? value, {int decimals = 0}) {
    if (value == null) return '\u20B90';
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final sgn = intPart.startsWith('-') ? '-' : '';
    final digits = sgn.isEmpty ? intPart : intPart.substring(1);
    final grouped = _group(digits);
    final out = '\u20B9$grouped';
    if (parts.length > 1 && decimals > 0) return '$out.${parts[1]}';
    return out;
  }

  static String _group(String digits) {
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$last3';
  }
}
