import 'package:flutter_test/flutter_test.dart';

import 'package:vidhai/features/ai_live/field_extractor.dart';

void main() {
  group('extractAiLiveSuggestions', () {
    test('extracts English name, age, gender, address', () {
      final s = extractAiLiveSuggestions(
          'My name is Ravi Kumar and I am 42 years old male and I live in Pollachi');
      expect(s.name, 'Ravi Kumar');
      expect(s.age, '42');
      expect(s.gender, 'Male');
      expect(s.address, 'Pollachi');
    });

    test('extracts Tanglish (English+Tamil)', () {
      final s = extractAiLiveSuggestions(
          'என் பெயர் Murugan, வயது 35, நான் பொள்ளாச்சியில் இருக்கிறேன்');
      expect(s.name, contains('Murugan'));
      expect(s.age, '35');
      expect(s.address, 'பொள்ளாச்சியில்');
    });

    test('extracts pure Tamil gender and age', () {
      final s = extractAiLiveSuggestions('வயது 45, பெண்');
      expect(s.age, '45');
      expect(s.gender, 'Female');
    });

    test('extracts Hindi', () {
      final s = extractAiLiveSuggestions(
          'मेरा नाम राम है, उम्र 40, मैं दिल्ली में रहता हूं');
      expect(s.name, contains('राम'));
      expect(s.age, '40');
      expect(s.address, 'दिल्ली');
    });

    test('empty or filler input returns empty suggestions', () {
      expect(extractAiLiveSuggestions('').isEmpty, isTrue);
      expect(extractAiLiveSuggestions('   ').isEmpty, isTrue);
      expect(
          extractAiLiveSuggestions('some random words here').isEmpty, isTrue);
    });

    test('guards absurd ages', () {
      expect(extractAiLiveSuggestions('I am 500 years old').age, isNull);
      expect(extractAiLiveSuggestions('age 0').age, isNull);
    });

    test('never fabricates unmarked fields', () {
      final s = extractAiLiveSuggestions('I am 30 years old');
      expect(s.age, '30');
      expect(s.name, isNull);
      expect(s.gender, isNull);
      expect(s.address, isNull);
    });

    test('gender shortcut letters are not matched inside words', () {
      final s = extractAiLiveSuggestions('M and I am 30');
      // "m" on its own is a valid Male marker, but "am"/"name" must not trigger.
      expect(s.gender, 'Male');
      final s2 = extractAiLiveSuggestions('I am fine');
      expect(s2.gender, isNull);
    });
  });
}
