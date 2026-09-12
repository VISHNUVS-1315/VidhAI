import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/features/assistant/assistant_field_registry.dart';
import 'package:vidhai/locale/locale.dart';

void main() {
  group('AssistantFieldRegistry.confirmation', () {
    test('destructive action needs confirmation first, then runs', () async {
      final reg = AssistantFieldRegistry.instance;
      var ran = false;
      reg.registerAction(
          'test_screen',
          AssistantActionEntry(
            action: 'delete',
            label: 'Delete farm',
            destructive: true,
            run: (_) async {
              ran = true;
              return {'deleted': true};
            },
          ));

      final pending =
          await reg.runAction('test_screen', action: 'delete', args: const {});
      expect(ran, isFalse);
      expect(pending['needsConfirmation'], isTrue);
      expect(pending['summary'], 'Delete farm');
      expect(pending['confirmLabelKey'], isNull);
      expect(pending['cancelLabelKey'], isNull);

      final confirmed = await reg.runAction('test_screen',
          action: 'delete', args: const {}, confirmed: true);
      expect(ran, isTrue);
      expect(confirmed['deleted'], isTrue);

      reg.unregisterAction('test_screen', 'delete');
    });

    test('requiresConfirmation submit is reviewed before it runs', () async {
      final reg = AssistantFieldRegistry.instance;
      var ran = false;
      reg.registerAction(
          'form_screen',
          AssistantActionEntry(
            action: 'submit',
            label: 'Save the farm',
            requiresConfirmation: true,
            confirmLabelKey: 'save',
            cancelLabelKey: 'review',
            run: (_) async {
              ran = true;
              return {'saved': true};
            },
          ));

      final pending =
          await reg.runAction('form_screen', action: 'submit', args: const {});
      expect(ran, isFalse);
      expect(pending['needsConfirmation'], isTrue);
      expect(pending['confirmLabelKey'], 'save');
      expect(pending['cancelLabelKey'], 'review');

      final confirmed = await reg.runAction('form_screen',
          action: 'submit', args: const {}, confirmed: true);
      expect(ran, isTrue);
      expect(confirmed['saved'], isTrue);

      reg.unregisterAction('form_screen', 'submit');
    });

    test('non-destructive non-confirm action runs immediately', () async {
      final reg = AssistantFieldRegistry.instance;
      var ran = false;
      reg.registerAction(
          'quick_screen',
          AssistantActionEntry(
            action: 'peek',
            label: 'Peek',
            run: (_) async {
              ran = true;
              return {'ok': true};
            },
          ));

      final result =
          await reg.runAction('quick_screen', action: 'peek', args: const {});
      expect(ran, isTrue);
      expect(result['ok'], isTrue);
      expect(result['needsConfirmation'], isNull);

      reg.unregisterAction('quick_screen', 'peek');
    });
  });

  group('Locale assistant strings', () {
    test('assistant greeting keys resolve for every supported language', () {
      const langs = [
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
        'ur',
      ];
      for (final lang in langs) {
        final loc = AppLocalizations(lang);
        expect(loc.assistantWelcome.length, greaterThan(0), reason: lang);
        expect(loc.assistantHint.length, greaterThan(0), reason: lang);
        expect(loc.assistantReview.length, greaterThan(0), reason: lang);
      }
      // Short, user-controlled greeting (spec Part 1/4/27): manual open says
      // "Welcome back…", first Home entry says "Welcome back to VidhAI…".
      final en = AppLocalizations('en');
      expect(en.assistantWelcome, 'Welcome back. How can I help you?');
      expect(
        en.assistantWelcomeBack,
        'Welcome back to VidhAI. How can I help you?',
      );
      expect(en.assistantWelcome.contains("I'm VidhAI"), isFalse);
      expect(en.assistantWelcomeBack.length,
          greaterThan(en.assistantWelcome.length));
    });
  });
}
