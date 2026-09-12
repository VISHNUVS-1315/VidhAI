import 'pest_analysis.dart';
import 'pest_photo_input.dart';

/// A single entry in the farmer's Workspace notepad.
///
/// [WorkspaceNoteType.manual] notes are fully user-written text.
/// [WorkspaceNoteType.pest] notes are snapshots saved from a pest / disease
/// analysis result (they stay readable even if the analysis history clears).
class WorkspaceNote {
  final String id;
  final WorkspaceNoteType type;
  final String title;
  final String body;
  final String farmId; // '' = "No farm"
  final String farmName;
  final String crop;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Pest-analysis snapshot (only meaningful for type == pest).
  final bool isHealthy;
  final String issue;
  final String severity;
  final double confidence;
  final List<String> symptoms;
  final List<String> affectedParts;
  final List<String> causes;
  final RemedyAdvice remedy;
  final List<String> prevention;
  final String farmingMethod;
  final List<String> imageRefs;

  // Multi-photo pest-detection case data (structured, never flattened).
  final String source; // 'pest_detection' for multi-photo cases
  final String sessionId;
  final List<WorkspacePhoto> photos;

  const WorkspaceNote({
    required this.id,
    required this.type,
    required this.title,
    this.body = '',
    this.farmId = '',
    this.farmName = '',
    this.crop = '',
    required this.createdAt,
    required this.updatedAt,
    this.isHealthy = false,
    this.issue = '',
    this.severity = 'low',
    this.confidence = 0,
    this.symptoms = const [],
    this.affectedParts = const [],
    this.causes = const [],
    this.remedy = const RemedyAdvice(),
    this.prevention = const [],
    this.farmingMethod = '',
    this.imageRefs = const [],
    this.source = '',
    this.sessionId = '',
    this.photos = const [],
  });

  /// Builds a notepad entry from a saved pest analysis result.
  factory WorkspaceNote.fromAnalysis(PestAnalysisRecord r) => WorkspaceNote(
        id: 'ws_${DateTime.now().millisecondsSinceEpoch}_${r.id}',
        type: WorkspaceNoteType.pest,
        title: r.isHealthy ? r.crop : (r.issue.isEmpty ? r.crop : r.issue),
        body: r.remedy.isEmpty ? '' : r.remedy.action,
        farmId: r.farmId,
        farmName: r.farmName,
        crop: r.crop,
        createdAt: r.createdAt,
        updatedAt: r.createdAt,
        isHealthy: r.isHealthy,
        issue: r.issue,
        severity: r.severity,
        confidence: r.confidence,
        symptoms: r.symptoms,
        causes: r.causes,
        remedy: r.remedy,
        prevention: r.prevention,
        farmingMethod: r.farmingMethod,
        imageRefs: r.imageRefs,
      );

  /// Builds a structured Workspace case from a completed multi-photo
  /// pest-detection analysis. Keeps every photo tied to its plant part and
  /// farmer observation instead of flattening the case into a paragraph.
  factory WorkspaceNote.fromPestCase({
    required PestAnalysisRecord record,
    required List<WorkspacePhoto> photos,
    String source = 'pest_detection',
  }) =>
      WorkspaceNote(
        id: 'ws_pest_${DateTime.now().millisecondsSinceEpoch}_${record.id}',
        type: WorkspaceNoteType.pest,
        title: record.isHealthy
            ? record.crop
            : (record.issue.isEmpty ? record.crop : record.issue),
        body: record.remedy.isEmpty ? '' : record.remedy.action,
        farmId: record.farmId,
        farmName: record.farmName,
        crop: record.crop,
        createdAt: record.createdAt,
        updatedAt: record.createdAt,
        isHealthy: record.isHealthy,
        issue: record.issue,
        severity: record.severity,
        confidence: record.confidence,
        symptoms: record.symptoms,
        affectedParts: record.affectedParts,
        causes: record.causes,
        remedy: record.remedy,
        prevention: record.prevention,
        farmingMethod: record.farmingMethod,
        imageRefs: record.imageRefs,
        source: source,
        sessionId: record.id,
        photos: photos,
      );

  WorkspaceNote copyWith({
    String? title,
    String? body,
    String? farmId,
    String? farmName,
    String? crop,
    DateTime? updatedAt,
  }) =>
      WorkspaceNote(
        id: id,
        type: type,
        title: title ?? this.title,
        body: body ?? this.body,
        farmId: farmId ?? this.farmId,
        farmName: farmName ?? this.farmName,
        crop: crop ?? this.crop,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isHealthy: isHealthy,
        issue: issue,
        severity: severity,
        confidence: confidence,
        symptoms: symptoms,
        causes: causes,
        remedy: remedy,
        prevention: prevention,
        farmingMethod: farmingMethod,
        imageRefs: imageRefs,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'farmId': farmId,
        'farmName': farmName,
        'crop': crop,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isHealthy': isHealthy,
        'issue': issue,
        'severity': severity,
        'confidence': confidence,
        'symptoms': symptoms,
        'affectedParts': affectedParts,
        'causes': causes,
        'remedy': remedy.toMap(),
        'prevention': prevention,
        'farmingMethod': farmingMethod,
        'imageRefs': imageRefs,
        'source': source,
        'sessionId': sessionId,
        'photos': photos.map((p) => p.toMap()).toList(),
      };

  factory WorkspaceNote.fromMap(Map<String, dynamic> m) {
    final typeName = m['type'] ?? 'manual';
    return WorkspaceNote(
      id: m['id'] ?? '',
      type: typeName == 'pest'
          ? WorkspaceNoteType.pest
          : WorkspaceNoteType.manual,
      title: m['title'] ?? '',
      body: m['body'] ?? '',
      farmId: m['farmId'] ?? '',
      farmName: m['farmName'] ?? '',
      crop: m['crop'] ?? '',
      createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(m['updatedAt'] ?? '') ?? DateTime.now(),
      isHealthy: m['isHealthy'] ?? false,
      issue: m['issue'] ?? '',
      severity: m['severity'] ?? 'low',
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
      symptoms: (m['symptoms'] as List?)?.map((e) => '$e').toList() ?? const [],
      affectedParts:
          (m['affectedParts'] as List?)?.map((e) => '$e').toList() ?? const [],
      causes: (m['causes'] as List?)?.map((e) => '$e').toList() ?? const [],
      remedy: m['remedy'] is Map
          ? RemedyAdvice.fromMap(Map<String, dynamic>.from(m['remedy']))
          : const RemedyAdvice(),
      prevention:
          (m['prevention'] as List?)?.map((e) => '$e').toList() ?? const [],
      farmingMethod: m['farmingMethod'] ?? '',
      imageRefs:
          (m['imageRefs'] as List?)?.map((e) => '$e').toList() ?? const [],
      source: m['source'] ?? '',
      sessionId: m['sessionId'] ?? '',
      photos: (m['photos'] as List?)
              ?.whereType<Map>()
              .map((e) => WorkspacePhoto.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}

/// Origin of a workspace note.
enum WorkspaceNoteType { manual, pest }

/// Day bucket used to group workspace notes (Today / Yesterday / Older).
enum WorkspaceDayGroup { today, yesterday, older }

WorkspaceDayGroup workspaceDayGroup(DateTime now, DateTime date) {
  final thisDay = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(date.year, date.month, date.day);
  final diff = thisDay.difference(thatDay).inDays;
  if (diff <= 0) return WorkspaceDayGroup.today;
  if (diff == 1) return WorkspaceDayGroup.yesterday;
  return WorkspaceDayGroup.older;
}
