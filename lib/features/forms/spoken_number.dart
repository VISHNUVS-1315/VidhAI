/// Converts spoken number phrases — English, Tamil and Tanglish (plus common
/// Hindi words) — into stable digits, so speech that says "ஏழு" or "seven"
/// always fills a form with "7" no matter what the AI transcribed.
///
/// Pure Dart, no dependencies: fully unit-testable.
class SpokenNumber {
  const SpokenNumber._();

  static const Map<String, num> _ones = {
    // English
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
    // Tamil
    'சுழி': 0, 'பூஜ்யம்': 0, 'ஒன்று': 1, 'ஒரு': 1, 'இரண்டு': 2,
    'இரு': 2, 'மூன்று': 3, 'நான்கு': 4, 'ஐந்து': 5, 'ஆறு': 6,
    'ஏழு': 7, 'எட்டு': 8, 'ஒன்பது': 9,
    // Hindi (common)
    'शून्य': 0, 'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4, 'पाँच': 5,
    'छह': 6, 'सात': 7, 'आठ': 8, 'नौ': 9,
  };

  static const Map<String, num> _teens = {
    'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19,
    // Tamil 10-19
    'பத்து': 10, 'பதினொன்று': 11, 'பன்னிரண்டு': 12, 'பதின்மூன்று': 13,
    'பதினான்கு': 14, 'பதினைந்து': 15, 'பதினாறு': 16, 'பதினேழு': 17,
    'பதினெட்டு': 18, 'பத்தொன்பது': 19,
  };

  static const Map<String, num> _tens = {
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
    'seventy': 70, 'eighty': 80, 'ninety': 90,
    // Tamil 20-90 (compound stems, e.g. இருபது = 20)
    'இருபது': 20, 'முப்பது': 30, 'நாற்பது': 40, 'ஐம்பது': 50,
    'அறுபது': 60, 'எழுபது': 70, 'எண்பது': 80, 'தொண்ணூறு': 90,
    // Hindi
    'बीस': 20, 'तीस': 30, 'चालीस': 40, 'पचास': 50, 'साठ': 60,
    'सत्तर': 70, 'अस्सी': 80, 'नब्बे': 90,
  };

  static const Map<String, num> _multipliers = {
    'hundred': 100, 'thousand': 1000, 'million': 1000000,
    'billion': 1000000000, 'lakh': 100000, 'crore': 10000000,
    // Tamil
    'நூறு': 100, 'ஆயிரம்': 1000, 'லட்சம்': 100000, 'கோடி': 10000000,
    // Hindi
    'सौ': 100, 'हज़ार': 1000, 'लाख': 100000, 'करोड़': 10000000,
  };

  /// Decimal indicators (English + Tamil "point").
  static const List<String> _pointWords = ['point', 'புள்ளி', 'dot'];

  /// Tamil half/quarter amounts commonly spoken for land size / age.
  static const Map<String, num> _fractions = {
    'அரை': 0.5,
    'முக்கால்': 0.75,
    'கால்': 0.25,
    'ஒன்றரை': 1.5,
    'இரண்டரை': 2.5,
    'மூன்றரை': 3.5,
    'நான்கரை': 4.5,
    'ஐந்தரை': 5.5,
    'ஆறரை': 6.5,
    'ஏழரை': 7.5,
    'எட்டரை': 8.5,
    'ஒன்பதரை': 9.5,
    'பத்தரை': 10.5,
  };

  /// Word tokens (letters + their combining marks, so Tamil vowel signs and
  /// virama stay inside their word) or number literals (with decimal/comma).
  static final RegExp _tokenPattern =
      RegExp(r'[\p{L}\p{M}]+|\d+(?:[.,]\d+)*', unicode: true);

  /// Rewrites every numeric phrase inside [input] to digits, leaving all other
  /// words untouched. E.g. "seven acres" -> "7 acres", "ஏழு எக்டேர்" ->
  /// "7 எக்டேர்", "twenty five" -> "25".
  static String normalizeMixed(String input) {
    var lastEnd = 0;
    final buffer = StringBuffer();
    final pending = <String>[];

    void flushPending() {
      if (pending.isEmpty) return;
      buffer.write(normalizeTokens(pending));
      pending.clear();
    }

    for (final match in _tokenPattern.allMatches(input)) {
      final sep = input.substring(lastEnd, match.start);
      final token = match.group(0)!;
      if (_isNumericRunToken(token)) {
        if (pending.isEmpty) buffer.write(sep);
        pending.add(token);
      } else {
        flushPending();
        buffer.write(sep);
        buffer.write(token);
      }
      lastEnd = match.end;
    }
    flushPending();
    buffer.write(input.substring(lastEnd));
    return buffer.toString();
  }

  /// Collapses a list of adjacent number words/literals into one number
  /// string. Shared by [normalizeMixed]; also used directly in tests.
  static String normalizeTokens(List<String> tokens) {
    final value = _numberFromTokens(tokens);
    if (value == null || !value.isFinite) return tokens.join(' ');
    return _format(value);
  }

  /// Pure number run → [num]? Returns null when the run isn't a number.
  static num? _numberFromTokens(List<String> tokens) {
    if (tokens.isEmpty) return null;
    var total = 0.0;
    var cur = 0.0;
    var decimal = false;
    var decimalFactor = 0.1;
    var sawAny = false;

    for (final raw in tokens) {
      final token = raw.toLowerCase();
      if (_pointWords.contains(token)) {
        decimal = true;
        sawAny = true;
        continue;
      }
      final frac = _fractions[raw];
      if (frac != null) {
        cur += frac;
        sawAny = true;
        continue;
      }
      final mult = _multipliers[token];
      if (mult != null) {
        if (cur == 0) cur = 1;
        cur *= mult;
        if (mult >= 1000) {
          total += cur;
          cur = 0;
        }
        sawAny = true;
        continue;
      }
      num v;
      final one = _ones[token];
      final teen = _teens[token];
      final tens = _tens[token];
      if (one != null) {
        v = one;
      } else if (teen != null) {
        v = teen;
      } else if (tens != null) {
        v = tens;
      } else {
        final parsed = num.tryParse(raw.replaceAll(',', ''));
        if (parsed == null) return null;
        v = parsed;
      }
      if (decimal) {
        total += v * decimalFactor;
        decimalFactor /= 10;
      } else {
        cur += v;
      }
      sawAny = true;
    }
    if (!sawAny) return null;
    return total + cur;
  }

  static bool _isNumericRunToken(String token) {
    final lower = token.toLowerCase();
    if (_ones.containsKey(lower) ||
        _teens.containsKey(lower) ||
        _tens.containsKey(lower) ||
        _multipliers.containsKey(lower) ||
        _fractions.containsKey(token) ||
        _pointWords.contains(lower)) {
      return true;
    }
    return double.tryParse(token.replaceAll(',', '')) != null;
  }

  static String _format(num value) {
    if (value == value.roundToDouble()) {
      return (value.round()).toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// Extracts the first recognisable numeric amount in [input] as a string,
  /// or null when there is none. "ஏழு எக்டேர்" -> "7".
  static String? extractNumber(String input) {
    final tokens =
        _tokenPattern.allMatches(input).map((m) => m.group(0)!).toList();
    for (var i = 0; i < tokens.length; i++) {
      final run = <String>[];
      var j = i;
      while (j < tokens.length && _isNumericRunToken(tokens[j])) {
        run.add(tokens[j]);
        j++;
      }
      if (run.isNotEmpty) {
        final value = _numberFromTokens(run);
        if (value != null && value.isFinite) return _format(value);
      }
    }
    return null;
  }
}
