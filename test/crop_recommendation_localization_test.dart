import 'package:flutter_test/flutter_test.dart';

import 'package:vidhai/locale/locale.dart';

/// Regression guard for the Top 10 Crop Recommendations red-screen crash:
/// "Null check operator used on a null value" thrown from AppLocalizations.t
/// (locale.dart) because the `cp_ai_based` key was missing from every
/// language dictionary. The ranked cards are lazily built by the ListView, so
/// the crash fired the moment the first ranked card entered the viewport.
void main() {
  const screenKeys = <String>[
    'cp_ai_based',
    'cp_ai_note',
    'cp_budget_not_set',
    'cp_choose_variety',
    'cp_compare',
    'cp_confidence',
    'cp_empty',
    'cp_estimated',
    'cp_factors',
    'cp_far_above_budget',
    'cp_harvest_hint',
    'cp_investment',
    'cp_loading',
    'cp_manual_check_hint',
    'cp_manual_check_title',
    'cp_offline',
    'cp_plan_generated',
    'cp_plan_generated_loading',
    'cp_planting_window',
    'cp_profit',
    'cp_refresh',
    'cp_result_label',
    'cp_revenue',
    'cp_risks',
    'cp_score',
    'cp_slightly_above_budget',
    'cp_start_crop',
    'cp_start_date',
    'cp_start_dialog_title',
    'cp_start_failed',
    'cp_subtitle',
    'cp_tasks_generated',
    'cp_title',
    'cp_today',
    'cp_view_farm',
    'cp_view_plan',
    'cp_within_budget',
    'cp_yield',
  ];

  test('t() must never throw for any screen key in any language', () {
    for (final code in AppLocalizations.allLanguageCodes) {
      final loc = AppLocalizations(code);
      for (final key in screenKeys) {
        final value = loc.t(key);
        expect(value.trim(), isNotEmpty,
            reason: '$code/$key resolved to an empty string');
      }
    }
  });

  test('cp_ai_based is translated in every language (root cause)', () {
    for (final code in AppLocalizations.allLanguageCodes) {
      expect(AppLocalizations.rawLookup(code, 'cp_ai_based'),
          isNotNull,
          reason: '$code is missing cp_ai_based');
      expect(AppLocalizations(code).t('cp_ai_based'),
          isNot('cp_ai_based'),
          reason: '$code fell back to the key instead of a translation');
    }
  });

  test('every screen key exists in all 13 languages', () {
    final missing = <String>[];
    for (final code in AppLocalizations.allLanguageCodes) {
      final keys = AppLocalizations.rawKeys(code);
      for (final key in screenKeys) {
        if (!keys.contains(key)) missing.add('$code/$key');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('missing keys fall back to the key instead of crashing', () {
    expect(AppLocalizations('en').t('cp_does_not_exist_xyz'),
        'cp_does_not_exist_xyz');
    expect(AppLocalizations('ta').t('cp_does_not_exist_xyz'),
        'cp_does_not_exist_xyz');
  });
}