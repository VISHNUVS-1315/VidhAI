/// Deterministic, pure-Dart analytics used by the farm-level recommendation
/// engine: figure parsing, sowing-calendar windows, rotation analysis and
/// per-acre economics scaling.
///
/// Every method is null-safe and degrades gracefully when a source figure is
/// missing or unparsable: missing data yields a neutral value instead of an
/// exception or a fabricated number.
library;

/// A numeric range with a midpoint, e.g. "₹25,000–35,000" -> 25000/30000/35000.
class CropRange {
  final double min;
  final double avg;
  final double max;

  const CropRange(this.min, this.avg, this.max);

  bool get isKnown => avg > 0;

  static const unknown = CropRange(0, 0, 0);
}

/// A closed sowing window in months 1..12 (1 = January).
class MonthWindow {
  final int startMonth;
  final int endMonth;

  const MonthWindow(this.startMonth, this.endMonth);

  bool contains(int month) {
    if (startMonth <= endMonth) return month >= startMonth && month <= endMonth;
    return month >= startMonth || month <= endMonth;
  }

  /// Forward distance in months from [month] to the first day of this window.
  int monthsUntilStart(int month) {
    if (contains(month)) return 0;
    final d = (startMonth - month) % 12;
    return d < 0 ? d + 12 : d;
  }

  /// Forward distance in months from [month] to the day after this window.
  int monthsSinceEnd(int month) {
    final end = endMonth;
    if (startMonth <= end) {
      if (month > end) return month - end;
    } else if (month > end && month >= startMonth) {
      return month - end;
    }
    return 0;
  }
}

/// Result of checking a crop's sowing calendar against the current month.
class CalendarStatus {
  /// One of: unknown, ideal_now, sow_soon, next_window, not_now.
  final String status;
  final List<MonthWindow> windows;

  const CalendarStatus(this.status, this.windows);

  static const unknown = CalendarStatus('unknown', []);

  bool get isKnown => status != 'unknown';
}

/// Result of comparing the candidate crop against the farm's planting history.
class RotationAnalysis {
  /// One of: same_crop, same_family, legume_benefit, good_rotation, no_history.
  final String status;
  final String detail;

  const RotationAnalysis(this.status, this.detail);

  /// 0..1 rotation score (1 = perfect rotation, 0 = same crop again).
  double get score {
    switch (status) {
      case 'same_crop':
        return 0.1;
      case 'same_family':
        return 0.3;
      case 'legume_benefit':
        return 0.95;
      case 'no_history':
        return 0.65;
      case 'good_rotation':
      default:
        return 0.85;
    }
  }
}

/// One line of the estimated per-acre cost breakdown.
class CostSplitLine {
  final String label;
  final double sharePct;

  const CostSplitLine(this.label, this.sharePct);
}

class CropAnalytics {
  CropAnalytics._();

  // ── Figure parsing ──────────────────────────────────────────────────────────

  /// Extracts the min/avg/max of the first numeric range found in [text].
  /// Returns [CropRange.unknown] when no usable number exists.
  static CropRange parseRange(String? text) {
    if (text == null || text.trim().isEmpty) return CropRange.unknown;
    final numbers = RegExp(r'\d+(?:[,\s]\d{3})*(?:\.\d+)?')
        .allMatches(text)
        .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '').replaceAll(' ', '')))
        .whereType<double>()
        .where((n) => n > 0)
        .toList();
    if (numbers.isEmpty) return CropRange.unknown;
    final sorted = [...numbers]..sort();
    final min = sorted.first;
    final max = sorted.last;
    return CropRange(
      min,
      numbers.length == 1 ? min : (min + max) / 2,
      max,
    );
  }

  /// Parses "120-130" (days) into (min, max). Returns (0,0) when unparsable.
  static (int, int) parseDurationRange(String? text) {
    final r = parseRange(text);
    if (!r.isKnown) return (0, 0);
    return (r.min.round(), r.max.round());
  }

  // ── Month windows ───────────────────────────────────────────────────────────

  static const Map<String, int> _monthIndex = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static int? _monthValue(String token) {
    final t = token.trim().toLowerCase();
    if (t.isEmpty) return null;
    final key = t.length >= 3 ? t.substring(0, 3) : t;
    return _monthIndex[key];
  }

  /// Parses sowing calendars such as "February-March", "June-July, January",
  /// "October-November", "Throughout year" into concrete month windows.
  static List<MonthWindow> parseMonthWindows(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    final lower = text.toLowerCase();
    if (lower.contains('throughout') || lower.contains('year-round') ||
        lower.contains('all year')) {
      return const [MonthWindow(1, 12)];
    }
    final windows = <MonthWindow>[];
    for (final part in text.split(',')) {
      final tokens = part
          .split(RegExp(r'[\s–—-]+'))
          .map((t) => _monthValue(t))
          .whereType<int>()
          .toList();
      if (tokens.isEmpty) continue;
      if (tokens.length == 1) {
        windows.add(MonthWindow(tokens.first, tokens.first));
      } else {
        windows.add(MonthWindow(tokens.first, tokens.last));
      }
    }
    return windows;
  }

  /// Compares [windows] against the current calendar [month] (1..12).
  static CalendarStatus calendarStatus(List<MonthWindow> windows, int month) {
    if (windows.isEmpty) return CalendarStatus.unknown;
    for (final w in windows) {
      if (w.contains(month)) {
        return CalendarStatus('ideal_now', windows);
      }
    }
    var bestDist = 13;
    for (final w in windows) {
      final sinceEnd = w.monthsSinceEnd(month);
      final untilStart = w.monthsUntilStart(month);
      final d = sinceEnd > 0 ? sinceEnd : untilStart;
      if (sinceEnd > 0 && sinceEnd <= 2) {
        return CalendarStatus('sow_soon', windows);
      }
      if (d < bestDist) bestDist = d;
    }
    if (bestDist == 1) return CalendarStatus('sow_soon', windows);
    if (bestDist <= 4) return CalendarStatus('next_window', windows);
    return CalendarStatus('not_now', windows);
  }

  // ── Economics ───────────────────────────────────────────────────────────────

  /// Profit margin in percent, guarded against missing revenue.
  static double profitMargin(double profit, double revenue) {
    if (revenue <= 0) return 0;
    final margin = profit / revenue * 100;
    return margin.clamp(0, 200).toDouble();
  }

  /// Rounds a rupee figure for display.
  static int moneyRound(double value) => value.round();

  /// Converts a farm size + unit pair to acres. Supports Acre and Hectare.
  static double? acresFromFarmSize(String size, String unit) {
    final acres = double.tryParse(size.trim());
    if (acres == null || acres <= 0) return null;
    final u = unit.toLowerCase();
    if (u.startsWith('hec') || u.contains('hect')) return acres * 2.47105;
    if (u.startsWith('gun')) return acres * 0.004; // guntha
    if (u.startsWith('sq')) return acres / 4046.8564224;
    if (u.startsWith('km') || u.startsWith('sq k')) return acres * 247.105;
    return acres;
  }

  // ── Rotation ────────────────────────────────────────────────────────────────

  /// Builds the rotation analysis for [candidateName] (family [candidateFamily],
  /// legume [candidateLegume]) against the farm's recent crop history.
  static RotationAnalysis rotationAnalysis({
    required String candidateName,
    required String candidateFamily,
    required bool candidateLegume,
    required List<String> previousCrops,
    required String Function(String cropName) familyOf,
  }) {
    final seen = <String>{};
    var conflict = false;
    var sameCropSeen = false;
    var legumeSeen = false;
    for (final prev in previousCrops) {
      final name = prev.trim().toLowerCase();
      if (name.isEmpty || !seen.add(name)) continue;
      if (name == candidateName.toLowerCase()) {
        sameCropSeen = true;
        continue;
      }
      final fam = familyOf(prev).toLowerCase();
      if (fam.isNotEmpty && fam == candidateFamily.toLowerCase()) {
        conflict = true;
      }
      if (fam == 'fabaceae') legumeSeen = true;
    }
    if (sameCropSeen) {
      return const RotationAnalysis(
          'same_crop',
          'The same crop was grown recently; repeating it raises pest and '
              'soil-fertility risk.');
    }
    if (conflict) {
      return const RotationAnalysis(
          'same_family',
          'A crop from the same family was grown recently; rotating to a '
              'different family is safer for soil health.');
    }
    if (candidateLegume && legumeSeen) {
      return const RotationAnalysis(
          'good_rotation',
          'Complements the recent pulse crop; keep nitrogen build-up and '
              'rotate again next season.');
    }
    if (legumeSeen) {
      return const RotationAnalysis(
          'legume_benefit',
          'Follows a legume crop, which replenishes soil nitrogen — a good '
              'rotation.');
    }
    if (previousCrops.isEmpty) {
      return const RotationAnalysis(
          'no_history', 'No previous crop history is recorded on this farm.');
    }
    return const RotationAnalysis(
        'good_rotation', 'Rotates well away from the crops previously grown.');
  }
}