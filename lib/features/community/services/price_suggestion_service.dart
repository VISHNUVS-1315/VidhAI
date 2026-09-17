import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/services/market_price_service.dart';

/// Result of a real-market price suggestion for a crop.
///
/// All numeric figures come from the AGMARKNET-backed MarketPriceService
/// (never invented). `explanation` is an optional, best-effort 1–2 sentence
/// Groq note served by the backend — it never contributes numbers.
class PriceSuggestionResult {
  final double? referencePerKg;
  final double? minPerKg;
  final double? maxPerKg;

  /// District-level reference used; empty when the fallback is state-level.
  final String districtUsed;
  final String marketName;
  final bool usedStateFallback;
  final bool fromCache;
  final bool stale;
  final String source;
  final String? date;

  /// Optional short AI explanation (≤2 sentences), text only.
  final String? explanation;

  bool get isEmpty => referencePerKg == null || !referencePerKg!.isFinite;

  const PriceSuggestionResult({
    this.referencePerKg,
    this.minPerKg,
    this.maxPerKg,
    this.districtUsed = '',
    this.marketName = '',
    this.usedStateFallback = false,
    this.fromCache = false,
    this.stale = false,
    this.source = '',
    this.date,
    this.explanation,
  });
}

/// Fetches real market references for create/edit price suggestions.
///
/// Resolution order: preferred district (selected community district) → same
/// state fallback (clearly marked). Normalisation to ₹/kg happens server-side.
class PriceSuggestionService {
  PriceSuggestionService._();
  static final PriceSuggestionService instance = PriceSuggestionService._();

  Future<PriceSuggestionResult> suggest({
    required String state,
    required String district,
    required String commodity,
    String language = 'en',
  }) async {
    final market = MarketPriceService.instance;
    final cleanCommodity = commodity.trim();
    final cleanState = state.trim();
    if (cleanCommodity.isEmpty || cleanState.isEmpty) {
      return const PriceSuggestionResult();
    }

    // 1) Prefer the selected district.
    final districtPayload = await market.fetchPrices(
      state: cleanState,
      district: district,
      commodity: cleanCommodity,
    );
    var matched = _recordsFor(districtPayload.prices, cleanCommodity);

    if (matched.isEmpty) {
      // 2) Fall back to the whole state, clearly marked for the UI.
      final statePayload = await market.fetchPrices(
        state: cleanState,
        commodity: cleanCommodity,
      );
      matched = _recordsFor(statePayload.prices, cleanCommodity);
      return _build(
        matched,
        const PriceSuggestionResult(
          usedStateFallback: true,
          districtUsed: '',
        ),
        payload: statePayload,
      );
    }

    return _build(
      matched,
      PriceSuggestionResult(
        districtUsed: district,
        fromCache: districtPayload.fromCache,
        stale: districtPayload.stale,
        source: districtPayload.source,
        date: districtPayload.latestDate,
      ),
      payload: districtPayload,
    );
  }

  PriceSuggestionResult _build(
    List<MarketPriceRecord> records,
    PriceSuggestionResult base, {
    required MarketPricePayload payload,
  }) {
    final perKg = records
        .map((r) => r.normalizedPricePerKg)
        .whereType<double>()
        .where((v) => v.isFinite && v > 0)
        .toList();
    if (perKg.isEmpty) return const PriceSuggestionResult();

    final reference = perKg.reduce((a, b) => a + b) / perKg.length;
    final min = perKg.reduce((a, b) => a < b ? a : b);
    final max = perKg.reduce((a, b) => a > b ? a : b);

    final markets =
        records.map((r) => r.market).where((m) => m.isNotEmpty).toSet();
    return PriceSuggestionResult(
      referencePerKg: reference,
      minPerKg: min,
      maxPerKg: max,
      districtUsed: base.districtUsed,
      marketName: markets.isEmpty ? '' : markets.first,
      usedStateFallback: base.usedStateFallback,
      fromCache: base.fromCache || payload.fromCache,
      stale: base.stale || payload.stale,
      source: base.source.isNotEmpty ? base.source : payload.source,
      date: base.date ?? payload.latestDate,
    );
  }

  List<MarketPriceRecord> _recordsFor(
      List<MarketPriceRecord> records, String commodity) {
    final clean = commodity.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    final exact = records.where((r) {
      final name = r.commodity.trim().toLowerCase();
      return name == clean && r.hasReliablePerKg;
    }).toList();
    if (exact.isNotEmpty) return exact;

    return records.where((r) {
      final name = r.commodity.trim().toLowerCase();
      return name.contains(clean) && r.hasReliablePerKg;
    }).toList();
  }
}