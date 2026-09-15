import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/pest_analysis.dart';
import 'package:vidhai/data/models/pest_photo_input.dart';
import 'package:vidhai/services/ai/nvidia_vision_service.dart';

/// Analyzer signature used by the Pest & Diseases module.
typedef PestDiseaseAnalyzer = Future<PestAnalysisRecord> Function({
  required List<Uint8ListLike> images,
  required String crop,
  required String farmingMethod,
  String? language,
  String farmId,
  String farmName,
});

/// Analyzer signature for the multi-photo plant-part workflow.
typedef MultiPestAnalyzer = Future<PestAnalysisRecord> Function({
  required List<PestPhotoInput> photos,
  required String crop,
  required String farmingMethod,
  String? language,
  String farmId,
  String farmName,
});

/// Persistence + NVIDIA vision analyzer for pest analyses.
///
/// Records are stored under `users/{uid}/pest_analyses/{id}` with a
/// `SharedPreferences` fallback cache per farm (`pest_analyses_<farmId>`).
/// Temporary ("no farm") analyses are never persisted.
class PestAnalysisService {
  PestAnalysisService._();

  static final PestAnalysisService instance = PestAnalysisService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Builds a strict, safety-first prompt for the vision model.
  String buildPrompt({required String crop, required String farmingMethod}) {
    final preference = farmingMethod.trim().isEmpty
        ? 'Your farming preferences are not set; keep the advice balanced.'
        : 'The farmer uses "$farmingMethod". Recommend no more than ONE '
            'primary remedy (organic if the farm prefers organic/natural '
            'methods, otherwise chemical), matched to that method.';
    return '''
You are an agronomist assistant for Indian farmers. Analyze the provided plant photos.

Crop under analysis: ${crop.isEmpty ? 'unknown, infer from the photos' : crop}
$preference

STRICT SAFETY RULES:
- Never state 100% certainty. Cap confidence at 0.95.
- Never invent specific dosage amounts, ml/g per litre, or spray schedules.
  Keep the remedy application guidance general ("follow the product label",
  "apply as directed by your local agronomist").
- If the photos are too unclear, blurry, dark or not close enough, set
  "imageQuality" to "poor" and keep confidence low.
- If the plant looks healthy, set "condition" to "healthy" and leave
  "issue" empty.

Reply with ONLY one JSON object (no markdown fences, no comments) using this
exact schema:
{
  "crop": "detected or given crop name",
  "condition": "healthy" or "issue",
  "issue": "identified pest or disease common name, or empty string",
  "type": "pest" or "disease" or "",
  "symptoms": ["short observable symptoms on the plant"],
  "severity": "low" or "medium" or "high",
  "confidence": <0 to 0.95 number>,
  "causes": ["most likely contributing causes"],
  "affectedParts": ["which plant parts show symptoms, e.g. leaf, stem, fruit"],
  "remedy": {
    "input": "recommended fertiliser/input name if relevant, else empty",
    "inputType": "organic" or "chemical" or "none",
    "action": "what the farmer should do, step by step, general guidance only",
    "frequency": "general frequency guidance only",
    "duration": "general duration guidance only",
    "reason": "why this remedy fits the farming method"
  },
  "prevention": ["preventive practices to reduce recurrence"],
  "imageQuality": "good" or "poor"
}
''';
  }

  /// Builds a strict, safety-first prompt for multi-photo plant-part analysis.
  ///
  /// Each photo's plant part and farmer observation are spelled out so the
  /// model analyzes the photos together as one case instead of treating them
  /// as unrelated requests.
  String buildMultiPhotoPrompt({
    required String crop,
    required String farmingMethod,
    required List<PestPhotoInput> photos,
  }) {
    final preference = farmingMethod.trim().isEmpty
        ? 'Your farming preferences are not set; keep the advice balanced.'
        : 'The farmer uses "$farmingMethod". Recommend no more than ONE '
            'primary remedy (organic if the farm prefers organic/natural '
            'methods, otherwise chemical), matched to that method.';

    final photoLines = <String>[];
    var index = 0;
    for (final p in photos) {
      index++;
      final part = p.plantPart?.code ?? 'unspecified';
      final observation = p.observation.trim().isEmpty
          ? 'No observation given by the farmer.'
          : p.observation.trim();
      photoLines.add('Photo ${index <= 9 ? '0$index' : '$index'}: '
          'plant part = ${part.replaceAll('_', ' ')}, '
          'farmer observation = "$observation"');
    }

    return '''
You are an agronomist assistant for Indian farmers. A farmer has uploaded
photos of DIFFERENT parts of ONE affected plant. Analyze all photos TOGETHER
as a single case - combine the visual evidence across the parts plus the
farmer observations before concluding.

Crop under analysis: ${crop.isEmpty ? 'unknown, infer from the photos' : crop}
$preference

What each photo shows:
${photoLines.join('\n')}

STRICT SAFETY RULES:
- Never state 100% certainty. Cap confidence at 0.95.
- If the combined evidence is not enough to identify the pest or disease,
  do NOT fabricate a diagnosis. Say "issue" is empty, keep confidence low and
  advise consulting an agronomist.
- Never invent specific dosage amounts, ml/g per litre, or spray schedules.
  Keep the remedy application guidance general ("follow the product label",
  "apply as directed by your local agronomist").
- If the photos are too unclear, blurry, dark or not close enough, set
  "imageQuality" to "poor" and keep confidence low.
- If the plant looks healthy, set "condition" to "healthy" and leave
  "issue" empty.

Reply with ONLY one JSON object (no markdown fences, no comments) using this
exact schema:
{
  "crop": "detected or given crop name",
  "condition": "healthy" or "issue",
  "issue": "identified pest or disease common name, or empty string",
  "type": "pest" or "disease" or "",
  "symptoms": ["short observable symptoms combining all photos"],
  "severity": "low" or "medium" or "high",
  "confidence": <0 to 0.95 number>,
  "causes": ["most likely contributing causes"],
  "affectedParts": ["plant part codes from the list above that show symptoms"],
  "remedy": {
    "input": "recommended fertiliser/input name if relevant, else empty",
    "inputType": "organic" or "chemical" or "none",
    "action": "what the farmer should do, step by step, general guidance only",
    "frequency": "general frequency guidance only",
    "duration": "general duration guidance only",
    "reason": "why this remedy fits the farming method"
  },
  "prevention": ["preventive practices to reduce recurrence"],
  "imageQuality": "good" or "poor"
}
''';
  }

  /// Default analyzer backed by [NvidiaVisionService].
  Future<PestAnalysisRecord> analyzeWithNvidia({
    required List<Uint8ListLike> images,
    required String crop,
    required String farmingMethod,
    String? language,
    String farmId = '',
    String farmName = '',
  }) async {
    final va = await NvidiaVisionService.instance.analyze(
      images: images,
      prompt: buildPrompt(crop: crop, farmingMethod: farmingMethod),
      language: language,
    );
    if (!va.success) {
      throw Exception(va.error ?? 'Image analysis failed.');
    }
    final record = parsePestAnalysisJson(
      va.text,
      farmId: farmId,
      farmName: farmName,
      farmingMethod: farmingMethod,
    );
    if (record == null) {
      throw const FormatException('Could not interpret the analysis result.');
    }
    return record;
  }

  /// Default multi-photo analyzer backed by [NvidiaVisionService].
  ///
  /// Sends every photo together with its plant part context in one request;
  /// it does NOT create a second pest-detection pipeline.
  Future<PestAnalysisRecord> analyzeMultiPhotos({
    required List<PestPhotoInput> photos,
    required String crop,
    required String farmingMethod,
    String? language,
    String farmId = '',
    String farmName = '',
  }) async {
    if (photos.isEmpty || photos.every((p) => !p.hasImage)) {
      throw const FormatException('No images provided.');
    }
    final images = <Uint8ListLike>[
      for (final p in photos)
        if (p.hasImage)
          Uint8ListLike(bytes: p.imageBytes, mimeType: p.mimeType),
    ];
    final va = await NvidiaVisionService.instance.analyze(
      images: images,
      prompt: buildMultiPhotoPrompt(
        crop: crop,
        farmingMethod: farmingMethod,
        photos: photos,
      ),
      language: language,
    );
    if (!va.success) {
      throw Exception(va.error ?? 'Image analysis failed.');
    }
    final record = parsePestAnalysisJson(
      va.text,
      farmId: farmId,
      farmName: farmName,
      farmingMethod: farmingMethod,
    );
    if (record == null) {
      throw const FormatException('Could not interpret the analysis result.');
    }
    return record;
  }

  /// Persists a farm-attached analysis. No-ops for temporary records.
  Future<void> save(PestAnalysisRecord record) async {
    if (record.farmId.isEmpty) return;
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('pest_analyses')
            .doc(record.id)
            .set(record.toMap());
      } catch (_) {
        // Offline — local cache below still records it.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'pest_analyses_${record.farmId}';
    final existing = prefs.getString(key);
    final list = <Map<String, dynamic>>[];
    if (existing != null && existing.isNotEmpty) {
      try {
        list.addAll((json.decode(existing) as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .where((m) => m['id'] != record.id));
      } catch (_) {}
    }
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<List<PestAnalysisRecord>> loadByFarm(String farmId) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('pest_analyses')
            .where('farmId', isEqualTo: farmId)
            .orderBy('createdAt', descending: true)
            .get();
        return snap.docs
            .map((d) => PestAnalysisRecord.fromMap(d.data()))
            .toList();
      } catch (_) {
        // Fall through to cache.
      }
    }
    return _loadCached(farmId);
  }

  Future<List<PestAnalysisRecord>> loadAll() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('pest_analyses')
            .orderBy('createdAt', descending: true)
            .get();
        return snap.docs
            .map((d) => PestAnalysisRecord.fromMap(d.data()))
            .toList();
      } catch (_) {
        // Fall through to caches.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final all = <PestAnalysisRecord>[];
    for (final key
        in prefs.getKeys().where((k) => k.startsWith('pest_analyses_'))) {
      final raw = prefs.getString(key) ?? '[]';
      try {
        all.addAll((json.decode(raw) as List)
            .map((m) =>
                PestAnalysisRecord.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList());
      } catch (_) {}
    }
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  Future<List<PestAnalysisRecord>> _loadCached(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pest_analyses_$farmId') ?? '[]';
    if (raw.isEmpty) return [];
    try {
      return (json.decode(raw) as List)
          .map((m) =>
              PestAnalysisRecord.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
