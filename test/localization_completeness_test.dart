import 'package:flutter_test/flutter_test.dart';

import 'package:vidhai/locale/locale.dart';

/// Development validation (spec 20/26): every base (English) key must exist
/// and be non-empty in every supported language. Missing/empty translations
/// must never silently fall back to English.
void main() {
  test('all 13 locales are registered', () {
    expect(AppLocalizations.allLanguageCodes, [
      'en',
      'ta',
      'te',
      'kn',
      'ml',
      'hi',
      'bn',
      'mr',
      'gu',
      'pa',
      'or',
      'as',
      'ur'
    ]);
  });

  test('no missing or empty translations in any of the 13 languages', () {
    final base = AppLocalizations.rawLookup('en', '_unused');
    expect(base, isNull, reason: 'sanity: rawLookup must not fall back');

    final enKeys = AppLocalizations.rawKeys('en');
    expect(enKeys, isNotEmpty);

    final problems = <String>[];
    for (final code in AppLocalizations.allLanguageCodes) {
      final keys = AppLocalizations.rawKeys(code);
      final missing = enKeys.where((k) => !keys.contains(k)).toList()..sort();
      if (missing.isNotEmpty) {
        problems
            .add('$code: ${missing.length} missing -> ${missing.join(', ')}');
      }
      final empty = keys.where((k) {
        final v = AppLocalizations.rawLookup(code, k);
        return v == null || v.trim().isEmpty;
      }).toList();
      if (empty.isNotEmpty) {
        problems.add('$code: ${empty.length} empty -> ${empty.join(', ')}');
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
