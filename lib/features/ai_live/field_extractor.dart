/// Heuristic extraction of personal-details fields from an AI Live transcript.
///
/// Marker-driven and intentionally conservative: a field is only suggested
/// when the speaker used an explicit marker (e.g. "my name is", `வயது`,
/// "i live in", `பெயர்`). Results ALWAYS go through a review/confirm step in
/// the UI before any form field is touched. Tanglish/mixed text is handled by
/// matching both English and Indic markers in the same pass.
library;

class AiLiveSuggestions {
  const AiLiveSuggestions({this.name, this.gender, this.age, this.address});

  final String? name;
  final String? gender;
  final String? age;
  final String? address;

  bool get isEmpty =>
      (name == null || name!.isEmpty) &&
      (gender == null || gender!.isEmpty) &&
      (age == null || age!.isEmpty) &&
      (address == null || address!.isEmpty);

  bool get hasName => (name ?? '').isNotEmpty;
  bool get hasGender => (gender ?? '').isNotEmpty;
  bool get hasAge => (age ?? '').isNotEmpty;
  bool get hasAddress => (address ?? '').isNotEmpty;
}

const Map<String, String> _genderMapping = {
  // male
  'male': 'Male',
  'man': 'Male',
  'm': 'Male',
  'boy': 'Male',
  'ஆண்': 'Male',
  'புருஷன்': 'Male',
  'पुरुष': 'Male',
  'आदमी': 'Male',
  'పురుషుడు': 'Male',
  'ಪುರುಷ': 'Male',
  'പുരുഷൻ': 'Male',
  'পুরুষ': 'Male',
  'पुरूष': 'Male',
  'પુરુષ': 'Male',
  'ਪੁਰਸ਼': 'Male',
  'ପୁରୁଷ': 'Male',
  'পুৰুষ': 'Male',
  'مرد': 'Male',
  // female
  'female': 'Female',
  'woman': 'Female',
  'f': 'Female',
  'girl': 'Female',
  'பெண்': 'Female',
  'சிறுமி': 'Female',
  'स्त्री': 'Female',
  'महिला': 'Female',
  'మహిళ': 'Female',
  'ಹೆಣ್ಣು': 'Female',
  'ಮಹಿಳೆ': 'Female',
  'സ്ത്രീ': 'Female',
  'মহিলা': 'Female',
  'महीला': 'Female',
  'સ્ત્રી': 'Female',
  'ମହିଳା': 'Female',
  'ਔਰਤ': 'Female',
  'خاتون': 'Female',
  // other
  'other': 'Other',
  'மற்றவர்': 'Other',
  'अन्य': 'Other',
  'మరొకటి': 'Other',
  'ഇതരം': 'Other',
  'অন্যান্য': 'Other',
  'અન્ય': 'Other',
  'অন্য': 'Other',
  'آخر': 'Other',
};

final List<RegExp> _agePatterns = [
  RegExp(r'\b(\d{1,3})\s*(?:year|years|yrs|yr)\s*old\b', caseSensitive: false),
  RegExp(r'\b(?:age|aged)\s*(?:is|=|:)?\s*(\d{1,3})\b', caseSensitive: false),
  RegExp(
      r'(?:^|[^\p{L}\p{N}])(?:வயது|उम्र|वर्ष|వయస్సు|ವಯಸ್ಸು|പ്രായം|বয়স|વય|ਉਮਰ|ବୟସ|বয়স|عمر)\s*(?:is|=|:)?\s*(\d{1,3})\b',
      unicode: true),
  RegExp(r"\b(?:i am|i'm|எனக்கு)\s*(\d{1,3})\b", caseSensitive: false),
];

/// (marker-regex, max captured word-count, stop-words to trim from the end)
final List<(String, int)> _nameMarkers = [
  (r'my name is', 3),
  (r"my name's", 3),
  (r'i am called', 3),
  (r'name is', 3),
  (r'என் பெயர்', 4),
  (r'நான் பெயர்', 4),
  (r'मेरा नाम', 4),
  (r'میرا نام', 4),
  (r'నా పేరు', 4),
  (r'ನನ್ನ ಹೆಸರು', 4),
  (r'എന്റെ പേര്', 4),
  (r'আমার নাম', 4),
  (r'माझे नाव', 4),
  (r'મારું નામ', 4),
  (r'মোৰ নাম', 4),
  (r'ମୋର ନାମ', 4),
];

final List<String> _nameStopWords = [
  'is',
  'and',
  'aged',
  'age',
  'years',
  'year',
  'old',
  'i',
  'am',
  'from',
  'வயது',
  'எனக்கு',
  'நான்',
  'आयु',
  'उम्र',
  'سال',
  'and',
];

const Set<String> _addressMarkers = {
  'i live in',
  'i live at',
  'i stay in',
  'i am staying in',
  'my address is',
  'my current address is',
  'my village is',
  'my town is',
  'my city is',
  'i am from',
  "i'm from",
  'from the village',
  'address',
  'முகவரி',
  'விலாசம்',
  'ஊர்',
  'சொந்த ஊர்',
  'இருப்பிடம்',
  'मेरा पता',
  'पता है',
  'मेरा गांव',
  'गांव',
  'गाँव',
  'నా గ్రామం',
  'গ্রাম',
  'மா ஊர்',
  'ನಮ್ಮ ಊರು',
  'ನನ್ನ ಊರು',
  'എന്റെ വീട്',
  'വിലാസം',
  'ঠিকানা',
  'गाव',
  'माझा पत्ता',
  'મારું ગામ',
  'আমাৰ গাঁও',
  'ମୋ ଗାଁ',
  'میرا گاؤں',
};

const String _sentenceEnding = r'[.!?।|?¿!;:]';

/// Sentence-style residence patterns: "`<place> <residence-verb>`". Used after
/// the literal markers above for vernacular phrasing.
final List<RegExp> _addressPatterns = [
  RegExp(
      r'நான்\s+(.+?)\s+(?:இருக்கிறேன்|இருக்கின்றேன்|வசிக்கிறேன்|இருக்கிறோம்|irukiren)',
      caseSensitive: false),
  RegExp(r'मैं\s+(.+?)\s+(?:रहता हूँ|रहती हूँ|रहता हूं|रहती हूं)',
      caseSensitive: false),
  RegExp(r'నేను\s+(.+?)\s+ఉంటాను'),
  RegExp(r'njan\s+(.+?)\s+(?:thamasikkunnu|tamasikkunnu|vasikkunnu)',
      caseSensitive: false),
];

final RegExp _nameCapture =
    RegExp(r'([^\s,.।|?¿!;:]+(?:\s+[^\s,.।|?¿!;:]+){0,2})');

/// Extracts [AiLiveSuggestions] from one or more utterances of raw transcript.
AiLiveSuggestions extractAiLiveSuggestions(String raw, {String? languageCode}) {
  final text = raw.trim();
  if (text.isEmpty) return const AiLiveSuggestions();

  return AiLiveSuggestions(
    name: _extractName(text),
    gender: _extractGender(text),
    age: _extractAge(text),
    address: _extractAddress(text),
  );
}

String? _extractName(String text) {
  final lower = text.toLowerCase();
  for (final (marker, wordLimit) in _nameMarkers) {
    final idx = lower.indexOf(marker.toLowerCase());
    if (idx < 0) continue;
    final start = idx + marker.length;
    if (start >= text.length) continue;
    final rest = text.substring(start);
    final match = _nameCapture.firstMatch(rest);
    if (match == null) continue;
    var candidate = match.group(1)!.trim();
    // Trim trailing stop words.
    var changed = true;
    while (changed && candidate.isNotEmpty) {
      changed = false;
      for (final sw in _nameStopWords) {
        final re =
            RegExp(r'\s+' + RegExp.escape(sw) + r'$', caseSensitive: false);
        if (re.hasMatch(candidate)) {
          candidate = candidate.replaceAll(re, '').trim();
          changed = true;
        }
      }
    }
    // Trim leading particles (and/i/from).
    for (final sw in ['and ', 'i ', 'am ', 'from ', 'நான் ', 'is ']) {
      final re = RegExp(r'^' + RegExp.escape(sw), caseSensitive: false);
      if (re.hasMatch(candidate)) {
        candidate = candidate.replaceAll(re, '').trim();
      }
    }
    // Keep at most a few words; require at least one letter.
    final words = candidate
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(wordLimit)
        .toList();
    if (words.isEmpty) continue;
    final name = words.join(' ');
    if (_looksLikeName(name)) return name;
  }
  return null;
}

bool _looksLikeName(String candidate) {
  if (candidate.length < 2 || candidate.length > 40) return false;
  // Reject anything that is mostly digits.
  final digitCount =
      candidate.codeUnits.where((u) => u >= 0x30 && u <= 0x39).length;
  return digitCount < candidate.length ~/ 2;
}

String? _extractGender(String text) {
  for (final entry in _genderMapping.entries) {
    final key = entry.key.toLowerCase();
    final idx = text.toLowerCase().indexOf(key);
    if (idx >= 0) {
      // Avoid attributing "m" inside other words: "m" must be standalone-ish.
      if (entry.key == 'm' || entry.key == 'f') {
        final before = idx > 0 ? text[idx - 1] : ' ';
        final after = idx + entry.key.length < text.length
            ? text[idx + entry.key.length]
            : ' ';
        if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch('$before$after')) {
          continue;
        }
      }
      return entry.value;
    }
  }
  return null;
}

String? _extractAge(String text) {
  for (final pattern in _agePatterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final age = int.tryParse(match.group(1)!);
    if (age != null && age >= 1 && age <= 120) return age.toString();
  }
  return null;
}

String? _extractAddress(String text) {
  final lower = text.toLowerCase();
  String? best;
  var bestIndex = text.length;
  for (final marker in _addressMarkers) {
    final idx = lower.indexOf(marker.toLowerCase());
    if (idx < 0) continue;
    final start = idx + marker.length;
    if (start >= text.length) continue;
    if (idx >= bestIndex) continue; // use the earliest marker for stability
    var rest = text.substring(start).trim();
    if (rest.isEmpty) continue;
    // Sentence ends at first sentence-ending punctuation.
    final endMatch = RegExp(_sentenceEnding).allMatches(rest);
    if (endMatch.isNotEmpty) rest = rest.substring(0, endMatch.first.start);
    // Drop trailing filler connectors.
    rest = _trimTrailingFillers(rest);
    if (rest.isNotEmpty) {
      best = rest;
      bestIndex = idx;
    }
  }
  if (best != null && best.trim().isNotEmpty) return best.trim();

  // Sentence-style patterns: "`<place> <residence-verb>`" in common languages.
  for (final pattern in _addressPatterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final value = match.group(1)?.trim();
    if (value != null && value.isNotEmpty) {
      return _trimTrailingFillers(value);
    }
  }
  return null;
}

String _trimTrailingFillers(String rest) {
  var out = rest;
  for (final sw in const [
    'irukiren',
    'irukken',
    'vasikkiren',
    'residing',
    'live',
    'staying',
    'நான் இருக்கிறேன்',
    'இருக்கிறேன்',
    'இருக்கின்றேன்',
    'வசிக்கிறேன்',
    'है',
    'रहते हैं',
    'रहता हूं',
    'में',
  ]) {
    final re = RegExp(RegExp.escape(sw) + r'\s*$', caseSensitive: false);
    out = out.replaceAll(re, '').trim();
  }
  return out.replaceAll(RegExp(r'[,\s]+$'), '');
}
