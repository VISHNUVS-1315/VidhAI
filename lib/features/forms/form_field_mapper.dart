import 'spoken_number.dart';

/// Maps a spoken/transcribed value onto a real form field's expected format.
///
/// Numeric fields (area, size, age, phone, price, …) get a clean digit string
/// ("ஏழு" or "seven" -> "7"); units stay untouched elsewhere. Enum/option
/// fields are left exactly as supplied because the brain already received the
/// approved options.
///
/// Pure Dart, no dependencies: fully unit-testable.
class FormFieldMapper {
  const FormFieldMapper();

  /// Field keys treated as numeric (area/size/age/phone/amount…). Matched
  /// case-insensitively against the field id with separators ignored, so this
  /// set uses the separator-stripped lowercase forms.
  static const Set<String> numericFields = {
    'farmarea',
    'farmsize',
    'farmland',
    'area',
    'extent',
    'age',
    'phone',
    'mobile',
    'pincode',
    'pin',
    'amount',
    'price',
    'cost',
    'number',
    'count',
    'quantity',
    'yield',
    'qty',
    'population',
    'acres',
    'hectares',
    'cents',
    'width',
    'length',
    'distance',
    'weight',
    'acresland',
    'total',
    'distancevalue',
    'farmwide',
    'landholding',
    'landarea',
  };

  /// Normalizes a spoken value for the given field.
  /// [options] are the registered enum options (from GET_FORM_FIELDS); when
  /// present and matching nothing, the value is returned unchanged so the
  /// brain's confirmation flow stays in charge.
  String normalizeForField(String field, String value,
      {List<String>? options}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;

    if (isNumericField(field)) {
      final number = SpokenNumber.extractNumber(trimmed);
      if (number != null) return number;
      return trimmed;
    }

    if (options != null && options.isNotEmpty) {
      final exact = options.firstWhere(
        (o) => o.toLowerCase() == trimmed.toLowerCase(),
        orElse: () => '',
      );
      if (exact.isNotEmpty) return exact;
      return trimmed;
    }

    return SpokenNumber.normalizeMixed(trimmed);
  }

  /// Whether [field] expects a numeric value.
  static bool isNumericField(String field) {
    final key = field.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    return numericFields.contains(key);
  }
}
