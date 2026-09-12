import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/features/forms/spoken_number.dart';

void main() {
  group('SpokenNumber.normalizeMixed', () {
    test('English words to digits', () {
      expect(SpokenNumber.normalizeMixed('seven acres'), '7 acres');
      expect(SpokenNumber.normalizeMixed('twenty five'), '25');
      expect(SpokenNumber.normalizeMixed('three hundred and twenty'),
          '300 and 20');
      expect(SpokenNumber.normalizeMixed('zero point five'), '0.5');
      expect(SpokenNumber.normalizeMixed('I need fifty kilograms'),
          'I need 50 kilograms');
    });

    test('Indian English large numbers', () {
      expect(SpokenNumber.normalizeMixed('two lakh three thousand'), '203000');
      expect(SpokenNumber.normalizeMixed('one crore two lakh'), '10200000');
    });

    test('Tamil words to digits', () {
      expect(SpokenNumber.normalizeMixed('ஏழு எக்டேர்'), '7 எக்டேர்');
      expect(SpokenNumber.normalizeMixed('இருபத்தைந்து'), 'இருபத்தைந்து');
      expect(SpokenNumber.normalizeTokens(['இருபது', 'ஐந்து']), '25');
      expect(SpokenNumber.normalizeMixed('அரை ஏக்கர்'), '0.5 ஏக்கர்');
      expect(SpokenNumber.normalizeMixed('ஒன்றரை எக்டேர்'), '1.5 எக்டேர்');
    });

    test('code-switched Tanglish', () {
      expect(
        SpokenNumber.normalizeMixed('fill land with seven acres'),
        'fill land with 7 acres',
      );
    });

    test('already-numeric strings are unchanged', () {
      expect(SpokenNumber.normalizeMixed('phone is 9845012345'),
          'phone is 9845012345');
      expect(SpokenNumber.normalizeMixed('3.5'), '3.5');
    });

    test('multi-unit phrases', () {
      expect(
          SpokenNumber.normalizeMixed('7 acres 30 cents'), '7 acres 30 cents');
    });
  });

  group('SpokenNumber.extractNumber', () {
    test('extracts the first numeric amount', () {
      expect(SpokenNumber.extractNumber('ஏழு எக்டேர்'), '7');
      expect(SpokenNumber.extractNumber('age is five'), '5');
      expect(SpokenNumber.extractNumber('twenty five'), '25');
    });

    test('returns null when no number is present', () {
      expect(SpokenNumber.extractNumber('please fill my name'), isNull);
    });
  });

  group('SpokenNumber.normalizeTokens', () {
    test('compound English', () {
      expect(
          SpokenNumber.normalizeTokens(['one', 'hundred', 'twenty', 'three']),
          '123');
    });
    test('plain word', () {
      expect(SpokenNumber.normalizeTokens(['hello']), 'hello');
    });
  });
}
