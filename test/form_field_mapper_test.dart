import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/features/forms/form_assistant_controller.dart';
import 'package:vidhai/features/forms/form_field_mapper.dart';

void main() {
  const mapper = FormFieldMapper();

  group('FormFieldMapper.isNumericField', () {
    test('numeric field keys', () {
      expect(FormFieldMapper.isNumericField('farm_area'), isTrue);
      expect(FormFieldMapper.isNumericField('farmSize'), isTrue);
      expect(FormFieldMapper.isNumericField('farm_size'), isTrue);
      expect(FormFieldMapper.isNumericField('age'), isTrue);
      expect(FormFieldMapper.isNumericField('phone'), isTrue);
      expect(FormFieldMapper.isNumericField('name'), isFalse);
      expect(FormFieldMapper.isNumericField('gender'), isFalse);
    });
  });

  group('FormFieldMapper.normalizeForField', () {
    test('numeric field turns spoken words into digits', () {
      expect(mapper.normalizeForField('farm_area', 'ஏழு'), '7');
      expect(mapper.normalizeForField('farm_size', 'seven acres'), '7');
      expect(mapper.normalizeForField('age', 'அறுபது'), '60');
      expect(mapper.normalizeForField('phone', '9845012345'), '9845012345');
    });

    test('non-numeric field keeps words but normalises embedded numbers', () {
      expect(mapper.normalizeForField('name', 'ஏழு மாடு'), '7 மாடு');
    });

    test('option fields resolve to the exact registered option', () {
      const options = ['Male', 'Female', 'Other'];
      expect(
          mapper.normalizeForField('gender', 'male', options: options), 'Male');
      expect(
        mapper.normalizeForField('gender', 'unknownvalue', options: options),
        'unknownvalue',
      );
    });
  });

  group('FormAssistantController.proposeField', () {
    const controller = FormAssistantController();

    test('numeric fill from spoken number is high confidence', () {
      final p = controller.proposeField(
        transcript: 'fill area with seven',
        field: 'farm_area',
        label: 'Area',
      );
      expect(p.value, '7');
      expect(p.needsClarification, isFalse);
      expect(p.confidence, greaterThan(0.9));
    });

    test('numeric fill with no number asks for clarification', () {
      final p = controller.proposeField(
        transcript: 'please put the value',
        field: 'farm_area',
        label: 'Area',
      );
      expect(p.needsClarification, isTrue);
      expect(p.confidence, lessThan(0.5));
    });

    test('value is extracted after the field label', () {
      final p = controller.proposeField(
        transcript: 'Area is five acres',
        field: 'farm_area',
        label: 'Area',
      );
      expect(p.value, '5');
    });
  });
}
