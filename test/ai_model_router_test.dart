import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/core/ai/ai_model_router.dart';

void main() {
  group('AiModelRouter.tierForHint', () {
    test('complex intent with high complexity routes to main', () {
      expect(
        AiModelRouter.tierForHint('plan my crop rotation for profit',
            complexity: 'high', intent: 'complex_query'),
        AiTier.main,
      );
    });

    test('explicit complex_query intent routes to main', () {
      expect(
        AiModelRouter.tierForHint('hello',
            intent: 'complex_query'),
        AiTier.main,
      );
    });

    test('long inputs (>220 chars) route to main', () {
      final long = List.filled(230, 'word ').join();
      expect(AiModelRouter.tierForHint(long), AiTier.main);
    });

    test('complex keyword routes to main', () {
      expect(
        AiModelRouter.tierForHint('what is the best pesticide for my crop?'),
        AiTier.main,
      );
    });

    test('short simple greeting routes to fast', () {
      expect(AiModelRouter.tierForHint('hi'), AiTier.fast);
      expect(AiModelRouter.tierForHint('hello'), AiTier.fast);
    });

    test('short simple command with market/weather routes to fast', () {
      expect(AiModelRouter.tierForHint('show weather'), AiTier.fast);
      expect(AiModelRouter.tierForHint('market price'), AiTier.fast);
    });

    test('short general text (<80 chars) routes to fast', () {
      expect(AiModelRouter.tierForHint('what time is it now'), AiTier.fast);
    });

    test('medium general text (>=80) routes to general', () {
      final medium =
          'can you tell me more about how the weather will affect my farm '
          'in the coming days and weeks ahead please';
      expect(medium.length, greaterThanOrEqualTo(80));
      expect(AiModelRouter.tierForHint(medium), AiTier.general);
    });
  });

  group('AiModelRouter helpers', () {
    test('wireName maps tiers to backend strings', () {
      expect(AiModelRouter.wireName(AiTier.main), 'main');
      expect(AiModelRouter.wireName(AiTier.general), 'general');
      expect(AiModelRouter.wireName(AiTier.fast), 'fast');
      expect(AiModelRouter.wireName(AiTier.creative), 'creative');
    });

    test('chatTiers excludes vision and safety', () {
      expect(AiModelRouter.chatTiers,
          containsAll([AiTier.main, AiTier.general, AiTier.fast, AiTier.creative]));
      expect(AiModelRouter.chatTiers, isNot(contains(AiTier.vision)));
      expect(AiModelRouter.chatTiers, isNot(contains(AiTier.safety)));
    });

    test('tierNames and tierModels cover every tier', () {
      for (final tier in AiTier.values) {
        expect(AiModelRouter.tierNames[tier], isNotNull);
        expect(AiModelRouter.tierModels[tier], isNotNull);
      }
    });

    test('general tier is served by Lightning while DeepSeek is disabled', () {
      expect(AiModelRouter.tierModels[AiTier.general],
          'nvidia/nemotron-3.5-lightning-30b-a3b');
      expect(AiModelRouter.tierNames[AiTier.general], 'Nemotron Lightning 30B');
      expect(AiModelRouter.tierModels[AiTier.general],
          AiModelRouter.tierModels[AiTier.fast]);
    });
  });
}