import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/services/market_price_service.dart';

MarketPriceRecord rec({
  String commodity = 'Tomato',
  String market = 'Koyembedu Market',
  String district = 'Chennai',
  String state = 'Tamil Nadu',
  double? modal = 3000,
  double? min = 2000,
  double? max = 4000,
  String unit = 'Quintal',
  double? factor,
  String date = '2026-09-10',
}) {
  final useFactor = factor ?? (unit == 'Quintal' ? 100 : null);
  return MarketPriceRecord(
    commodity: commodity,
    variety: 'Hybrid',
    state: state,
    district: district,
    market: market,
    minPrice: min,
    modalPrice: modal,
    maxPrice: max,
    originalUnit: unit,
    unitLabel: unit,
    conversionFactor: useFactor,
    normalizedPricePerKg:
        useFactor == null || modal == null ? null : modal / useFactor,
    date: date,
    source: 'VidhAI provider',
  );
}

void main() {
  group('MarketPriceRecord normalization', () {
    test('quintal factor converts to â‚¹/kg', () {
      final r = rec(modal: 3000);
      expect(r.conversionFactor, 100);
      expect(r.normalizedPricePerKg, 30);
      expect(r.hasReliablePerKg, isTrue);
      expect(r.trend, 'stable');
    });

    test('unsupported unit keeps prices but no reliable per-kg', () {
      final r = rec(unit: 'Bag', factor: null, modal: 900);
      expect(r.hasReliablePerKg, isFalse);
      expect(r.modalPrice, 900);
      expect(r.unitLabel, 'Bag');
    });

    test('per-kg unit keeps as-is', () {
      final r = rec(unit: 'kg', factor: 1, modal: 32);
      expect(r.normalizedPricePerKg, 32);
    });

    test('trend arrows from reported range only', () {
      expect(rec(modal: 3800, min: 1000, max: 4000).trend, 'up');
      expect(rec(modal: 1500, min: 1000, max: 4000).trend, 'down');
      expect(rec(modal: null).trend, 'stable');
    });

    test('toJson/fromJson round-trip', () {
      final r = rec();
      final back = MarketPriceRecord.fromJson(r.toJson());
      expect(back.commodity, 'Tomato');
      expect(back.market, 'Koyembedu Market');
      expect(back.normalizedPricePerKg, r.normalizedPricePerKg);
      expect(back.conversionFactor, 100);
      expect(back.date, '2026-09-10');
    });

    test('toCropMarketContext exposes only actual reported data', () {
      final r = rec(modal: 3000, factor: 100);
      final ctx = r.toCropMarketContext();
      expect(ctx['commodity'], 'Tomato');
      expect(ctx['normalizedPricePerKg'], 30);
      expect(ctx['state'], 'Tamil Nadu');
      expect(ctx['source'], isNotEmpty);
    });
  });

  group('MarketPricePayload', () {
    test('empty and full payloads round-trip through JSON', () {
      const empty = MarketPricePayload(prices: [], totalPriceRecords: 0);
      expect(empty.prices, isEmpty);
      final full = MarketPricePayload(
        prices: [rec()],
        statesWithData: ['Tamil Nadu', 'Andhra Pradesh'],
        commodities: ['Tomato', 'Onion'],
        latestDate: '2026-09-10',
        totalPriceRecords: 12,
        pricePerKgAvailable: 9,
        source: 'VidhAI provider',
        fetchedAt: '2026-09-11T00:00:00Z',
      );
      final back = MarketPricePayload.fromJson(full.toJson());
      expect(back.statesWithData, hasLength(2));
      expect(back.commodities, contains('Onion'));
      expect(back.totalPriceRecords, 12);
      expect(back.pricePerKgAvailable, 9);
      expect(back.prices.first.modalPrice, 3000);
    });
  });

  group('MarketFormat', () {
    test('Indian grouping with â‚¹ symbol', () {
      expect(MarketFormat.inr(100000), '\u20B91,00,000');
      expect(MarketFormat.inr(1234.5, decimals: 1), '\u20B91,234.5');
      expect(MarketFormat.inr(null), '\u20B90');
    });
  });

  group('MarketPriceService', () {
    test('query key is deterministic and filter-aware', () {
      final a = MarketPriceService.queryKey(
        state: 'Tamil Nadu',
        district: 'Chennai',
        commodity: 'Tomato',
      );
      final b = MarketPriceService.queryKey(
        state: 'Tamil Nadu',
        district: 'Chennai',
        commodity: 'Tomato',
      );
      final c = MarketPriceService.queryKey(
        state: 'Tamil Nadu',
        district: 'Chennai',
      );
      expect(a, isNotEmpty);
      expect(a, b);
      expect(c, isNot(a));
    });
  });
}
