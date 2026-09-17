/// Buyer-acceptance risk derived from the farmer's asking price relative to the
/// real AGMARKNET market reference (₹/kg). Pure logic, no plugins, testable.
library;

enum PriceRiskLevel {
  competitive,
  slightlyHigh,
  high,
  veryHigh,
}

class PriceRiskResult {
  final PriceRiskLevel level;

  /// asking / reference * 100 (e.g. 108 means asking is 108% of market).
  final double pctOfReference;

  /// True when the asking price is far below the current market range
  /// (asking < 90% of the reference) — surfaced as a gentle warning, not a color.
  final bool belowMarketStart;

  const PriceRiskResult({
    required this.level,
    required this.pctOfReference,
    required this.belowMarketStart,
  });

  /// True when no numeric reference is available so a risk level cannot be
  /// computed (falls back to the neutral/competitive presentation).
  bool get unknown => !pctOfReference.isFinite || pctOfReference <= 0;
}

class PriceRiskService {
  PriceRiskService._();

  static const double belowMarketRatio = 0.90;

  /// Thresholds per spec: ≤105 GREEN, 105–115 YELLOW, 115–130 ORANGE,
  /// >130 RED (percentage of the market reference price).
  static const double competitiveMax = 105;
  static const double slightlyHighMax = 115;
  static const double highMax = 130;

  static double percentageOfReference(double asking, double reference) {
    if (!asking.isFinite || asking <= 0 || !reference.isFinite || reference <= 0) {
      return double.nan;
    }
    return asking / reference * 100;
  }

  static PriceRiskLevel classify(double asking, double reference) {
    final pct = percentageOfReference(asking, reference);
    if (pct.isNaN) return PriceRiskLevel.competitive;
    if (pct <= competitiveMax) return PriceRiskLevel.competitive;
    if (pct <= slightlyHighMax) return PriceRiskLevel.slightlyHigh;
    if (pct <= highMax) return PriceRiskLevel.high;
    return PriceRiskLevel.veryHigh;
  }

  static PriceRiskResult evaluate(double? asking, double? reference) {
    if (asking == null || reference == null) {
      return const PriceRiskResult(
        level: PriceRiskLevel.competitive,
        pctOfReference: double.nan,
        belowMarketStart: false,
      );
    }
    final pct = percentageOfReference(asking, reference);
    return PriceRiskResult(
      level: classify(asking, reference),
      pctOfReference: pct,
      belowMarketStart: pct.isFinite && pct > 0 && pct < belowMarketRatio * 100,
    );
  }

  /// Suggested price band (₹/kg) around the market reference: a farmer who
  /// prices inside [minPct, maxPct] of the reference stays in the competitive
  /// ("green") zone. Returns [min, max] or (null, null) when no reference.
  static (double?, double?) suggestedBand(
    double? reference, {
    double minPct = 0.95,
    double maxPct = 1.05,
  }) {
    if (reference == null || !reference.isFinite || reference <= 0) {
      return (null, null);
    }
    final min = (reference * minPct / 0.5).roundToDouble() * 0.5;
    var max = (reference * maxPct / 0.5).roundToDouble() * 0.5;
    if (max < min) max = min;
    return (min < 1 ? 1 : min, max);
  }

  /// Default suggested asking price (midpoint of the band, rounded to 0.5).
  static double? suggestedAsking(double? reference) {
    final (min, max) = suggestedBand(reference);
    if (min == null || max == null) return null;
    return ((min + max) / 2 / 0.5).roundToDouble() * 0.5;
  }
}