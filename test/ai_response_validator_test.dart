import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/core/ai/ai_response_validator.dart';

void main() {
  group('AiResponseValidator.extractJsonObject', () {
    test('recovers a clean JSON object', () {
      final raw = '{"intent":"weather","complexity":"low"}';
      expect(AiResponseValidator.extractJsonObject(raw), raw);
    });

    test('strips surrounding prose', () {
      final raw = 'Here is your answer: {"ok": true} Thanks!';
      expect(AiResponseValidator.extractJsonObject(raw), '{"ok": true}');
    });

    test('handles markdown code fences', () {
      final raw = '```json\n{"a":1,"b":[1,2,3]}\n```';
      expect(
        AiResponseValidator.extractJsonObject(raw),
        '{"a":1,"b":[1,2,3]}',
      );
    });

    test('tolerates trailing commas inside object', () {
      final raw = '{"a":1,"b":2,}';
      expect(AiResponseValidator.extractJsonObject(raw), '{"a":1,"b":2}');
    });

    test('ignores braces inside string values', () {
      final raw = '{"note":"use {braces} here","v":1}';
      expect(AiResponseValidator.extractJsonObject(raw), '{"note":"use {braces} here","v":1}');
    });

    test('ignores escaping inside strings', () {
      final raw = r'{"quote":"he said \"{\"","v":2}';
      expect(AiResponseValidator.extractJsonObject(raw), raw);
    });

    test('returns null when no JSON object present', () {
      expect(AiResponseValidator.extractJsonObject('just some text'), isNull);
      expect(AiResponseValidator.extractJsonObject(''), isNull);
    });
  });

  group('AiResponseValidator.decodeJsonObject', () {
    test('decodes a typed map', () {
      final decoded = AiResponseValidator.decodeJsonObject<Map<String, dynamic>>(
        '{"intent":"weather"}',
      );
      expect(decoded, isNotNull);
      expect(decoded!['intent'], 'weather');
    });

    test('returns null when type does not match', () {
      final decoded = AiResponseValidator.decodeJsonObject<List<dynamic>>(
        '{"intent":"weather"}',
      );
      expect(decoded, isNull);
    });

    test('returns null on garbage input', () {
      expect(
        AiResponseValidator.decodeJsonObject<Map<String, dynamic>>('nope'),
        isNull,
      );
    });
  });

  group('AiResponseValidator.firstText / hasNonEmptyText', () {
    test('picks first non-empty key in order', () {
      const json = {'text': '', 'content': 'hello', 'description': 'world'};
      expect(
        AiResponseValidator.firstText(json, const ['text', 'content', 'description']),
        'hello',
      );
      expect(AiResponseValidator.hasNonEmptyText(json), isTrue);
    });

    test('reaches into nested maps', () {
      const json = {
        'stanza': {'text': 'nested answer', 'description': 'other'}
      };
      expect(
        AiResponseValidator.firstText(
            json, const ['stanza', 'text', 'content']),
        'nested answer',
      );
    });

    test('empty when nothing text-like present', () {
      const json = {'data': {'intent': 'weather'}};
      expect(
        AiResponseValidator.firstText(json, const ['text', 'content', 'description']),
        '',
      );
      expect(AiResponseValidator.hasNonEmptyText(json), isFalse);
    });
  });

  group('AiResponseValidator.isPlausibleAiText', () {
    test('rejects empty and placeholder text', () {
      expect(AiResponseValidator.isPlausibleAiText(''), isFalse);
      expect(AiResponseValidator.isPlausibleAiText('   '), isFalse);
    });

    test('rejects interrupted/mid-generation truncation markers', () {
      expect(AiResponseValidator.isPlausibleAiText('The answer is...'), isFalse);
    });

    test('accepts normal answers', () {
      expect(AiResponseValidator.isPlausibleAiText('The temperature is 30C'), isTrue);
      expect(AiResponseValidator.isPlausibleAiText('ok'), isTrue);
    });
  });
}