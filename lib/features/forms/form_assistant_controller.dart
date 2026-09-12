import 'form_field_mapper.dart';
import 'spoken_number.dart';

/// A proposed form-fill produced from a spoken turn, with an honest
/// confidence so the session can either apply it or ask for clarification.
class FormFillProposal {
  final String field;
  final String label;
  final String value;
  final double confidence;
  final String? clarification;

  const FormFillProposal({
    required this.field,
    required this.label,
    required this.value,
    required this.confidence,
    this.clarification,
  });

  bool get needsClarification => clarification != null;
}

/// Assists conversational form filling: normalizes transcribed values for the
/// fields mounted on the current screen and flags low-confidence fills so the
/// assistant asks before writing wrong data.
///
/// Pure Dart, no dependencies: fully unit-testable.
class FormAssistantController {
  const FormAssistantController({this.mapper = const FormFieldMapper()});

  final FormFieldMapper mapper;

  /// Returns a proposal for [field] from the spoken [transcript].
  ///
  /// Confidence ranges 0..1 and drops when the value has to be guessed or
  /// contains leftover number words (e.g. the field is numeric but "7" the
  /// transcript shows a unit the field can't store).
  FormFillProposal proposeField({
    required String transcript,
    required String field,
    required String label,
    List<String>? options,
  }) {
    final numeric = FormFieldMapper.isNumericField(field);
    final raw = _valueCandidate(transcript, field, label);
    final value = mapper.normalizeForField(field, raw, options: options);

    var confidence = 1.0;
    String? clarification;

    if (numeric) {
      final number = SpokenNumber.extractNumber(raw);
      if (number == null) {
        confidence = 0.3;
        clarification =
            'Please say the $label as a number (for example, "five" or "5").';
      } else if (value == number) {
        // A clean digit was extracted; the fill is trustworthy.
        confidence = 0.95;
      } else {
        confidence = 0.9;
      }
    } else {
      if (SpokenNumber.extractNumber(raw) != null &&
          SpokenNumber.normalizeMixed(raw).trim() != raw.trim()) {
        confidence = 0.9;
      }
    }

    if (confidence >= 0.9 && value.isEmpty) confidence = 0.6;

    return FormFillProposal(
      field: field,
      label: label,
      value: value,
      confidence: confidence,
      clarification: clarification,
    );
  }

  /// Finds the first mention of [field] (by id or label words) in the
  /// transcript and returns the text following it, up to the next sentence
  /// end. Falls back to the whole transcript for single-field turns.
  String _valueCandidate(String transcript, String field, String label) {
    final lower = transcript.toLowerCase();
    final fieldKey = field.toLowerCase();
    final labelKey = label.toLowerCase().trim();

    String? marker;
    if (fieldKey.isNotEmpty && lower.contains(fieldKey)) {
      marker = fieldKey;
    } else if (labelKey.isNotEmpty && lower.contains(labelKey)) {
      marker = labelKey;
    }

    if (marker != null && marker.length >= 3) {
      final start = lower.indexOf(marker) + marker.length;
      final tail = transcript.substring(start).trim();
      if (tail.isNotEmpty) {
        return tail.split(RegExp(r'[,.!?;]')).firstOrNull ?? transcript;
      }
    }
    return transcript.trim();
  }
}
