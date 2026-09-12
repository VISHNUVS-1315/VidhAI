import 'dart:convert';

/// Structured, safe result of a pest / disease image analysis.
///
/// Never persists when [farmId] is empty (temporary / "No farm" mode).
class PestAnalysisRecord {
  final String id;
  final String farmId;
  final String farmName;
  final String crop;
  final bool isHealthy;
  final String issue;
  final String issueType; // 'pest' | 'disease' | ''
  final List<String> symptoms;
  final String severity; // low | medium | high
  final double confidence; // 0..1, never 1.0
  final List<String> affectedParts; // which plant parts show symptoms
  final List<String> causes;
  final RemedyAdvice remedy;
  final List<String> prevention;
  final List<String> imageRefs;
  final bool imageQualityGood;
  final String farmingMethod;
  final DateTime createdAt;

  const PestAnalysisRecord({
    required this.id,
    this.farmId = '',
    this.farmName = '',
    required this.crop,
    required this.isHealthy,
    this.issue = '',
    this.issueType = '',
    this.symptoms = const [],
    this.severity = 'low',
    this.confidence = 0,
    this.affectedParts = const [],
    this.causes = const [],
    this.remedy = const RemedyAdvice(),
    this.prevention = const [],
    this.imageRefs = const [],
    this.imageQualityGood = true,
    this.farmingMethod = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'farmId': farmId,
        'farmName': farmName,
        'crop': crop,
        'isHealthy': isHealthy,
        'issue': issue,
        'issueType': issueType,
        'symptoms': symptoms,
        'severity': severity,
        'confidence': confidence,
        'affectedParts': affectedParts,
        'causes': causes,
        'remedy': remedy.toMap(),
        'prevention': prevention,
        'imageRefs': imageRefs,
        'imageQualityGood': imageQualityGood,
        'farmingMethod': farmingMethod,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PestAnalysisRecord.fromMap(Map<String, dynamic> m) =>
      PestAnalysisRecord(
        id: m['id'] ?? '',
        farmId: m['farmId'] ?? '',
        farmName: m['farmName'] ?? '',
        crop: m['crop'] ?? '',
        isHealthy: m['isHealthy'] ?? false,
        issue: m['issue'] ?? '',
        issueType: m['issueType'] ?? '',
        symptoms:
            (m['symptoms'] as List?)?.map((e) => '$e').toList() ?? const [],
        severity: m['severity'] ?? 'low',
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
        affectedParts:
            (m['affectedParts'] as List?)?.map((e) => '$e').toList() ??
                const [],
        causes: (m['causes'] as List?)?.map((e) => '$e').toList() ?? const [],
        remedy: m['remedy'] is Map
            ? RemedyAdvice.fromMap(Map<String, dynamic>.from(m['remedy']))
            : const RemedyAdvice(),
        prevention:
            (m['prevention'] as List?)?.map((e) => '$e').toList() ?? const [],
        imageRefs:
            (m['imageRefs'] as List?)?.map((e) => '$e').toList() ?? const [],
        imageQualityGood: m['imageQualityGood'] ?? true,
        farmingMethod: m['farmingMethod'] ?? '',
        createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      );
}

/// Agronomically-grounded remedy recommendation for one analysis.
class RemedyAdvice {
  final String input; // recommended input / fertiliser name ('' if none)
  final String inputType; // organic | chemical | none
  final String action;
  final String frequency;
  final String duration;
  final String reason;

  const RemedyAdvice({
    this.input = '',
    this.inputType = 'none',
    this.action = '',
    this.frequency = '',
    this.duration = '',
    this.reason = '',
  });

  bool get isEmpty =>
      input.isEmpty && action.isEmpty && frequency.isEmpty && duration.isEmpty;

  Map<String, dynamic> toMap() => {
        'input': input,
        'inputType': inputType,
        'action': action,
        'frequency': frequency,
        'duration': duration,
        'reason': reason,
      };

  factory RemedyAdvice.fromMap(Map<String, dynamic> m) => RemedyAdvice(
        input: m['input'] ?? '',
        inputType: m['inputType'] ?? 'none',
        action: m['action'] ?? '',
        frequency: m['frequency'] ?? '',
        duration: m['duration'] ?? '',
        reason: m['reason'] ?? '',
      );
}

/// Parses the vision model's strict-JSON reply into a [PestAnalysisRecord].
///
/// Returns null when no valid JSON object can be extracted. Never returns a
/// perfect-confidence result (capped well below 100%).
PestAnalysisRecord? parsePestAnalysisJson(
  String text, {
  String farmId = '',
  String farmName = '',
  String farmingMethod = '',
}) {
  if (text.trim().isEmpty) return null;
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var end = -1;
  for (var i = start; i < text.length; i++) {
    if (text[i] == '{') depth++;
    if (text[i] == '}') {
      depth--;
      if (depth == 0) {
        end = i + 1;
        break;
      }
    }
  }
  if (end < 0) return null;
  final json = jsonDecode(text.substring(start, end));
  if (json is! Map) return null;
  final Map<String, dynamic> j = Map<String, dynamic>.from(json);

  final condition = '${j['condition'] ?? ''}'.toLowerCase();
  final issue = '${j['issue'] ?? ''}'.trim();
  final isHealthy = condition == 'healthy' ||
      condition == 'none' ||
      condition.contains('health') ||
      issue.isEmpty ||
      '${j['type'] ?? ''}'.toLowerCase() == 'none';

  final rawConf = j['confidence'];
  double conf =
      rawConf is num ? rawConf.toDouble() : double.tryParse('$rawConf') ?? 0;
  if (conf > 1.0) conf = conf / 100.0; // tolerate percent output
  conf = conf.clamp(0.0, 0.95); // never claim 100% certainty

  final rawSeverity = '${json['severity'] ?? 'low'}'.toLowerCase();
  final severity = rawSeverity.startsWith('high')
      ? 'high'
      : rawSeverity.startsWith('medium') || rawSeverity.startsWith('moderate')
          ? 'medium'
          : 'low';

  var remedy = const RemedyAdvice();
  final rm = j['remedy'];
  if (rm is Map) {
    final input = '${rm['input'] ?? ''}'.trim();
    var inputType = '${rm['inputType'] ?? ''}'.toLowerCase();
    final method = farmingMethod.toLowerCase();
    if (inputType.isEmpty) {
      inputType = method.contains('organic') || method.contains('natural')
          ? 'organic'
          : 'chemical';
    }
    if (!['organic', 'chemical', 'none'].contains(inputType)) {
      inputType = 'none';
    }
    remedy = RemedyAdvice(
      input: input,
      inputType: inputType,
      action: '${j['action'] ?? ''}'.trim(),
      frequency: '${j['frequency'] ?? ''}'.trim(),
      duration: '${j['duration'] ?? ''}'.trim(),
      reason: '${j['reason'] ?? ''}'.trim(),
    );
  }

  return PestAnalysisRecord(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    farmId: farmId,
    farmName: farmName,
    crop: '${j['crop'] ?? ''}'.trim(),
    isHealthy: isHealthy,
    issue: issue,
    issueType: '${j['type'] ?? ''}'.toLowerCase(),
    symptoms: _stringList(j, 'symptoms'),
    severity: severity,
    confidence: conf,
    affectedParts: _stringList(j, 'affectedParts'),
    causes: _stringList(j, 'causes'),
    remedy: remedy,
    prevention: _stringList(j, 'prevention'),
    imageRefs: _stringList(j, 'imageRefs'),
    imageQualityGood: '${j['imageQuality'] ?? 'good'}' != 'poor',
    farmingMethod: farmingMethod,
    createdAt: DateTime.now(),
  );
}

List<String> _stringList(Map<String, dynamic> json, String key) =>
    (json[key] as List?)
        ?.map((e) => '$e'.trim())
        .where((e) => e.isNotEmpty)
        .toList() ??
    const [];
