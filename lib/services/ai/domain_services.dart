import 'ai_service.dart';
import 'ai_orchestrator.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 1. VoiceFormAI — Voice-to-field-value conversion
// ═══════════════════════════════════════════════════════════════════════════════

class VoiceFormAI {
  VoiceFormAI._();
  static final VoiceFormAI _instance = VoiceFormAI._();
  static VoiceFormAI get instance => _instance;

  final AiService _ai = AiService.instance;

  /// Processes speech input and maps it to a structured field value.
  /// Uses AI to interpret natural language and extract the correct value.
  Future<String> processVoiceInput(
    String field,
    String speechInput, {
    String language = 'en',
  }) async {
    try {
      final response = await _ai.getVoiceFormAssist(field, speechInput);

      if (response.success) {
        final parsed = response.jsonContent;
        if (parsed != null && parsed.containsKey('extractedValue')) {
          return parsed['extractedValue'] as String;
        }
        return response.content;
      }

      // Fallback: basic heuristic extraction
      return _fallbackExtraction(field, speechInput);
    } catch (e) {
      return _fallbackExtraction(field, speechInput);
    }
  }

  /// Returns the full AI response (including confidence, metadata) for display purposes.
  Future<Map<String, dynamic>> processVoiceInputDetailed(
    String field,
    String speechInput, {
    String language = 'en',
  }) async {
    try {
      final response = await _ai.getVoiceFormAssist(field, speechInput);

      if (response.success) {
        final parsed = response.jsonContent;
        if (parsed != null) {
          return Map<String, dynamic>.from(parsed);
        }
      }

      return {
        'extractedValue': _fallbackExtraction(field, speechInput),
        'confidence': 0.5,
        'source': 'fallback',
      };
    } catch (e) {
      return {
        'extractedValue': _fallbackExtraction(field, speechInput),
        'confidence': 0.3,
        'source': 'error_fallback',
        'error': e.toString(),
      };
    }
  }

  String _fallbackExtraction(String field, String speechInput) {
    final lower = speechInput.toLowerCase().trim();
    final fieldLower = field.toLowerCase();

    if (fieldLower.contains('phone') || fieldLower.contains('mobile')) {
      final digits = RegExp(r'\d{10}').firstMatch(lower)?.group(0);
      return digits ?? speechInput.replaceAll(RegExp(r'[^0-9]'), '');
    }

    if (fieldLower.contains('area') ||
        fieldLower.contains('acre') ||
        fieldLower.contains('hectare')) {
      final numMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
      return numMatch != null ? '${numMatch.group(1)} acres' : speechInput;
    }

    return speechInput;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. SoilAnalysisAI — Soil health analysis
// ═══════════════════════════════════════════════════════════════════════════════

class SoilAnalysisAI {
  SoilAnalysisAI._();
  static final SoilAnalysisAI _instance = SoilAnalysisAI._();
  static SoilAnalysisAI get instance => _instance;

  final AiService _ai = AiService.instance;

  /// Analyzes soil data and returns health score, recommendations, and warnings.
  Future<Map<String, dynamic>> analyzeSoil({
    required String soilType,
    required String ph,
    String? moisture,
    String? location,
  }) async {
    try {
      final request = SoilAnalysisRequest(
        soilType: soilType,
        ph: ph,
        moisture: moisture,
        location: location,
      );

      final response = await _ai.getSoilAnalysis(request);

      if (response.success) {
        final parsed = response.jsonContent;
        if (parsed != null) {
          return Map<String, dynamic>.from(parsed);
        }
      }

      return _fallbackAnalysis(soilType, ph, moisture);
    } catch (e) {
      return _fallbackAnalysis(soilType, ph, moisture);
    }
  }

  Map<String, dynamic> _fallbackAnalysis(
      String soilType, String ph, String? moisture) {
    final phValue = double.tryParse(ph) ?? 7.0;
    int score;
    if (phValue >= 6.0 && phValue <= 7.5) {
      score = 85;
    } else if (phValue >= 5.5 && phValue <= 8.0) {
      score = 70;
    } else {
      score = 50;
    }

    return {
      'soilType': soilType,
      'ph': ph,
      'moisture': moisture ?? 'Not measured',
      'healthScore': score,
      'healthRating': score >= 80
          ? 'Good'
          : score >= 60
              ? 'Fair'
              : 'Poor',
      'recommendations': [
        'Get a complete Soil Health Card from your nearest lab.',
        'Add organic matter to improve soil structure.',
        'Test for specific nutrient deficiencies.',
      ],
      'warnings': [],
      'source': 'fallback',
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. PestDetectionAI — Pest and disease identification
// ═══════════════════════════════════════════════════════════════════════════════

class PestDetectionAI {
  PestDetectionAI._();
  static final PestDetectionAI _instance = PestDetectionAI._();
  static PestDetectionAI get instance => _instance;

  final AiService _ai = AiService.instance;

  /// Detects pest or disease issues from crop name, images, and symptoms.
  /// Returns: detectedIssue, severity, treatment, prevention.
  Future<Map<String, dynamic>> detectPest({
    required String cropName,
    List<String>? imagePaths,
    String? symptoms,
  }) async {
    try {
      final request = PestDetectionRequest(
        cropName: cropName,
        imagePaths: imagePaths,
        symptoms: symptoms,
      );

      final response = await _ai.detectPest(request);

      if (response.success) {
        final parsed = response.jsonContent;
        if (parsed != null) {
          return Map<String, dynamic>.from(parsed);
        }
      }

      return _fallbackDetection(cropName, symptoms);
    } catch (e) {
      return _fallbackDetection(cropName, symptoms);
    }
  }

  Map<String, dynamic> _fallbackDetection(String cropName, String? symptoms) {
    return {
      'cropName': cropName,
      'detectedIssue': symptoms != null
          ? 'Symptoms reported: $symptoms — Manual identification recommended'
          : 'Unable to detect — please provide symptoms or upload images',
      'severity': 'Unknown',
      'severityScore': 0,
      'confidence': 0.0,
      'treatment': {
        'immediate': [
          'Consult your nearest KVK (Krishi Vigyan Kendra) for expert diagnosis.',
          'Isolate affected plants if possible.',
          'Take clear photos and share with agricultural officer.',
        ],
        'biological': [],
        'chemical': [],
      },
      'prevention': [
        'Regular field scouting.',
        'Maintain crop hygiene and field sanitation.',
        'Follow recommended IPM practices.',
      ],
      'source': 'fallback',
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. CropRecommendationAI — Crop selection guidance
// ═══════════════════════════════════════════════════════════════════════════════

class CropRecommendationAI {
  CropRecommendationAI._();
  static final CropRecommendationAI _instance = CropRecommendationAI._();
  static CropRecommendationAI get instance => _instance;

  final AiService _ai = AiService.instance;

  /// Recommends crops based on farm profile, returning a ranked list with reasoning.
  Future<List<Map<String, dynamic>>> recommend({
    required Map<String, dynamic> farmProfile,
    String? preferences,
  }) async {
    try {
      final season = farmProfile['season'] ?? _currentSeason();
      final request = RecommendationRequest(
        farmProfile: farmProfile,
        preferences: preferences,
        season: season,
        location: farmProfile['location'],
      );

      final response = await _ai.getCropRecommendation(request);

      if (response.success) {
        final parsed = response.jsonContent;
        if (parsed != null && parsed.containsKey('recommendations')) {
          final recs = parsed['recommendations'] as List;
          return recs.map((r) => Map<String, dynamic>.from(r)).toList();
        }
      }

      return _fallbackRecommendations(farmProfile);
    } catch (e) {
      return _fallbackRecommendations(farmProfile);
    }
  }

  List<Map<String, dynamic>> _fallbackRecommendations(
      Map<String, dynamic> profile) {
    return [
      {
        'crop': 'Rice',
        'suitabilityScore': 80,
        'reasoning': 'Versatile staple crop suitable for most Indian climates.',
        'riskLevel': 'Low',
      },
      {
        'crop': 'Wheat',
        'suitabilityScore': 75,
        'reasoning': 'Good Rabi option with MSP guarantee.',
        'riskLevel': 'Low',
      },
      {
        'crop': 'Pulses',
        'suitabilityScore': 70,
        'reasoning': 'Low input cost, fixes nitrogen, improves soil.',
        'riskLevel': 'Low',
      },
    ];
  }

  String _currentSeason() {
    final month = DateTime.now().month;
    if (month >= 6 && month <= 10) return 'kharif';
    if (month >= 11 || month <= 2) return 'rabi';
    return 'zaid';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 5. DailyTaskAI — Daily farm task generation
// ═══════════════════════════════════════════════════════════════════════════════

class DailyTaskAI {
  DailyTaskAI._();
  static final DailyTaskAI _instance = DailyTaskAI._();
  static DailyTaskAI get instance => _instance;

  final AiService _ai = AiService.instance;

  /// Generates prioritized daily tasks for given farms.
  /// Returns task list with priority, category, and estimated time.
  Future<List<Map<String, dynamic>>> generateTasks({
    required List<Map<String, dynamic>> farms,
    String? weather,
  }) async {
    try {
      final response = await _ai.getDailyTasks(farms);

      if (response.success) {
        final parsed = response.jsonContent;
        if (parsed != null && parsed.containsKey('farmTasks')) {
          final farmTasks = parsed['farmTasks'] as List;
          final List<Map<String, dynamic>> allTasks = [];

          for (final ft in farmTasks) {
            final taskList = ft['tasks'] as List;
            for (final task in taskList) {
              allTasks.add(Map<String, dynamic>.from(task));
            }
          }

          // Sort by priority
          allTasks.sort((a, b) {
            const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
            final aP = priorityOrder[a['priority']] ?? 2;
            final bP = priorityOrder[b['priority']] ?? 2;
            return aP.compareTo(bP);
          });

          return allTasks;
        }
      }

      return _fallbackTasks(farms);
    } catch (e) {
      return _fallbackTasks(farms);
    }
  }

  /// Returns farm-grouped tasks for UI display.
  Future<List<Map<String, dynamic>>> generateGroupedTasks({
    required List<Map<String, dynamic>> farms,
    String? weather,
  }) async {
    try {
      final response = await _ai.getDailyTasks(farms);

      if (response.success) {
        final parsed = response.jsonContent;
        if (parsed != null && parsed.containsKey('farmTasks')) {
          final farmTasks = parsed['farmTasks'] as List;
          return farmTasks.map((ft) => Map<String, dynamic>.from(ft)).toList();
        }
      }

      return [
        {'farmName': 'General', 'tasks': _fallbackTasks(farms)}
      ];
    } catch (e) {
      return [
        {'farmName': 'General', 'tasks': _fallbackTasks(farms)}
      ];
    }
  }

  List<Map<String, dynamic>> _fallbackTasks(List<Map<String, dynamic>> farms) {
    return [
      {
        'id': 'fb_1',
        'title': 'Field inspection',
        'description': 'Walk through your fields and check for visible issues.',
        'category': 'inspection',
        'priority': 'high',
        'estimatedTime': '30 min',
        'timeWindow': '6:00 AM – 8:00 AM',
      },
      {
        'id': 'fb_2',
        'title': 'Irrigation check',
        'description': 'Verify soil moisture and irrigate if needed.',
        'category': 'irrigation',
        'priority': 'high',
        'estimatedTime': '45 min',
        'timeWindow': '6:00 AM – 9:00 AM',
      },
      {
        'id': 'fb_3',
        'title': 'Record observations',
        'description': 'Log today\'s observations in the farm diary.',
        'category': 'documentation',
        'priority': 'low',
        'estimatedTime': '10 min',
        'timeWindow': 'Anytime',
      },
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 6. VidhAIChatService — Conversational farming assistant
// ═══════════════════════════════════════════════════════════════════════════════

class VidhAIChatService {
  VidhAIChatService._();
  static final VidhAIChatService _instance = VidhAIChatService._();
  static VidhAIChatService get instance => _instance;

  final AiOrchestrator _orchestrator = AiOrchestrator.instance;

  /// Single production chat path:
  /// AiOrchestrator -> AiChatBrain -> SecureApiClient -> Render.
  Future<String> chat(
    String message, {
    String language = 'en',
    Map<String, dynamic>? userProfile,
    List<Map<String, dynamic>>? farms,
  }) async {
    final result = await _orchestrator.process(
      input: message,
      language: language,
      userProfile: userProfile,
      farms: farms,
    );

    if (!result.failed && result.text.trim().isNotEmpty) {
      return result.text.trim();
    }

    return switch (result.error) {
      AiErrorKind.offline =>
        'No internet connection. Please reconnect and try again.',
      AiErrorKind.auth =>
        'Your sign-in session needs to be refreshed. Please sign in again.',
      AiErrorKind.timeout =>
        'The AI service took too long to respond. Please try again.',
      AiErrorKind.rateLimited =>
        'The AI service is busy right now. Please try again in a moment.',
      AiErrorKind.busy =>
        'The AI service is temporarily unavailable. Please try again shortly.',
      _ =>
        'The AI service could not complete this request. Please try again.',
    };
  }

  /// Returns the raw AIResponse for advanced UI rendering.
  Future<AIResponse> chatRaw(
    String message, {
    String language = 'en',
    Map<String, dynamic>? userProfile,
    List<Map<String, dynamic>>? farms,
  }) async {
    final result = await _orchestrator.process(
      input: message,
      language: language,
      userProfile: userProfile,
      farms: farms,
    );
    if (!result.failed && result.text.trim().isNotEmpty) {
      return AIResponse.ok(
        result.text.trim(),
        provider: 'render-router',
        metadata: const {'path': 'AiOrchestrator'},
      );
    }
    return AIResponse.fail(
      result.error?.name ?? 'AI request failed',
      provider: 'render-router',
    );
  }
}
