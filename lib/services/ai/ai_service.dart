import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ai_config.dart';
import 'secure_api_client.dart';

class ChatRequest {
  final String message;
  final String? language;
  final Map<String, dynamic>? context;

  const ChatRequest({
    required this.message,
    this.language,
    this.context,
  });

  Map<String, dynamic> toMap() => {
        'message': message,
        if (language != null) 'language': language,
        if (context != null) 'context': context,
      };
}

class CropAnalysisRequest {
  final String cropName;
  final String? growthStage;
  final List<String>? imagePaths;
  final Map<String, dynamic>? fieldData;
  final String? location;

  const CropAnalysisRequest({
    required this.cropName,
    this.growthStage,
    this.imagePaths,
    this.fieldData,
    this.location,
  });

  Map<String, dynamic> toMap() => {
        'cropName': cropName,
        if (growthStage != null) 'growthStage': growthStage,
        if (imagePaths != null) 'imagePaths': imagePaths,
        if (fieldData != null) 'fieldData': fieldData,
        if (location != null) 'location': location,
      };
}

class PestDetectionRequest {
  final String cropName;
  final List<String>? imagePaths;
  final String? symptoms;
  final String? location;
  final String? season;

  const PestDetectionRequest({
    required this.cropName,
    this.imagePaths,
    this.symptoms,
    this.location,
    this.season,
  });

  Map<String, dynamic> toMap() => {
        'cropName': cropName,
        if (imagePaths != null) 'imagePaths': imagePaths,
        if (symptoms != null) 'symptoms': symptoms,
        if (location != null) 'location': location,
        if (season != null) 'season': season,
      };
}

class SoilAnalysisRequest {
  final String soilType;
  final String ph;
  final String? moisture;
  final String? location;
  final Map<String, dynamic>? additionalData;

  const SoilAnalysisRequest({
    required this.soilType,
    required this.ph,
    this.moisture,
    this.location,
    this.additionalData,
  });

  Map<String, dynamic> toMap() => {
        'soilType': soilType,
        'ph': ph,
        if (moisture != null) 'moisture': moisture,
        if (location != null) 'location': location,
        if (additionalData != null) 'additionalData': additionalData,
      };
}

class RecommendationRequest {
  final Map<String, dynamic> farmProfile;
  final String? preferences;
  final String? season;
  final String? location;

  const RecommendationRequest({
    required this.farmProfile,
    this.preferences,
    this.season,
    this.location,
  });

  Map<String, dynamic> toMap() => {
        'farmProfile': farmProfile,
        if (preferences != null) 'preferences': preferences,
        if (season != null) 'season': season,
        if (location != null) 'location': location,
      };
}

class AIResponse {
  final bool success;
  final String content;
  final String provider;
  final Map<String, dynamic>? metadata;
  final String? error;

  const AIResponse({
    required this.success,
    required this.content,
    required this.provider,
    this.metadata,
    this.error,
  });

  factory AIResponse.ok(
    String content, {
    String provider = 'nvidia',
    Map<String, dynamic>? metadata,
  }) =>
      AIResponse(
        success: true,
        content: content,
        provider: provider,
        metadata: metadata,
      );

  factory AIResponse.fail(
    String error, {
    String provider = 'nvidia',
  }) =>
      AIResponse(
        success: false,
        content: '',
        provider: provider,
        error: error,
      );

  Map<String, dynamic> toMap() => {
        'success': success,
        'content': content,
        'provider': provider,
        if (metadata != null) 'metadata': metadata,
        if (error != null) 'error': error,
      };

  Map<String, dynamic>? get jsonContent {
    try {
      var text = content.trim();
      if (text.startsWith('&#96;&#96;&#96;json')) {
        text = text.substring(7);
      } else if (text.startsWith('&#96;&#96;&#96;')) {
        text = text.substring(3);
      }
      if (text.endsWith('&#96;&#96;&#96;')) {
        text = text.substring(0, text.length - 3);
      }
      final decoded = jsonDecode(text.trim());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}

/// Compatibility facade for app features that still use the older AiService
/// interface. Every method now routes to the same authenticated NVIDIA backend.
class AiService {
  AiService._();
  static final AiService _instance = AiService._();
  static AiService get instance => _instance;

  AIConfig _config = AIConfig.defaultConfig;
  AIConfig get config => _config;

  void configure(AIConfig config) {
    _config = config;
  }

  Future<void> loadConfig() async {
    _config = AIConfig.defaultConfig;
  }

  Future<AIResponse> chat(
    String message, {
    String? language,
    Map<String, dynamic>? context,
  }) {
    return _postChat(
      message,
      language: language,
      context: context,
      debugTag: 'AiService',
    );
  }

  Future<AIResponse> analyzeCrop(CropAnalysisRequest request) {
    return _jsonTask(
      'Analyze this crop status using only the supplied facts. '
      'Return JSON with cropName, healthScore, observations, recommendations, warnings.\n'
      'Input: ${jsonEncode(request.toMap())}',
      context: request.toMap(),
    );
  }

  Future<AIResponse> detectPest(PestDetectionRequest request) {
    return _jsonTask(
      'Analyze the reported crop symptoms. Do not claim certainty without an image. '
      'Return JSON with detectedIssue, severity, confidence, treatment, prevention.\n'
      'Input: ${jsonEncode(request.toMap())}',
      context: request.toMap(),
    );
  }

  Future<AIResponse> getVoiceFormAssist(
    String field,
    String speechInput,
  ) {
    return _jsonTask(
      'Extract the value for form field "$field" from the farmer speech. '
      'Return JSON only: {"extractedValue":"...","confidence":0.0}.\n'
      'Speech: $speechInput',
      context: {
        'field': field,
        'speechInput': speechInput,
      },
    );
  }

  Future<AIResponse> getSoilAnalysis(SoilAnalysisRequest request) {
    return _jsonTask(
      'Analyze this soil information for an Indian farm. Return JSON with '
      'soilType, ph, healthScore, healthRating, recommendations, warnings. '
      'Do not invent lab measurements.\n'
      'Input: ${jsonEncode(request.toMap())}',
      context: request.toMap(),
    );
  }

  Future<AIResponse> getDailyTasks(List<Map<String, dynamic>> farms) {
    return _jsonTask(
      'Create practical daily farm tasks from the supplied farms only. '
      'Return JSON exactly as {"farmTasks":[{"farmName":"...","tasks":[{"id":"...",'
      '"title":"...","description":"...","category":"...","priority":"high|medium|low",'
      '"estimatedTime":"...","timeWindow":"..."}]}]}.\n'
      'Farms: ${jsonEncode(farms)}',
      context: {'farms': farms},
    );
  }

  Future<AIResponse> getCropRecommendation(
    RecommendationRequest request,
  ) {
    return _jsonTask(
      'Recommend crops using all supplied farm data. Return JSON exactly as '
      '{"recommendations":[{"crop":"...","suitabilityScore":0,"reasoning":"...",'
      '"riskLevel":"Low|Medium|High"}]}. Never invent live prices.\n'
      'Input: ${jsonEncode(request.toMap())}',
      context: request.toMap(),
    );
  }

  Future<AIResponse> _jsonTask(
    String prompt, {
    Map<String, dynamic>? context,
  }) {
    return _postChat(
      prompt,
      language: 'en',
      context: context,
      debugTag: 'AiServiceJson',
    );
  }

  Future<AIResponse> _postChat(
    String message, {
    String? language,
    Map<String, dynamic>? context,
    String? debugTag,
  }) async {
    try {
      final data = await SecureApiClient.instance.post(
        '/ai/chat',
        {
          'messages': [
            {'role': 'user', 'content': message}
          ],
          if (language != null && language.isNotEmpty) 'language': language,
          if (context != null && context.isNotEmpty) 'context': context,
        },
        debugTag: debugTag,
      );

      return AIResponse(
        success: data['success'] == true,
        content: (data['content'] ?? '').toString(),
        provider: 'nvidia',
        metadata: data['metadata'] is Map
            ? Map<String, dynamic>.from(data['metadata'] as Map)
            : null,
        error: data['error']?.toString(),
      );
    } on SecureApiException catch (e) {
      debugPrint('[AiService] backend error: ${e.message}');
      return AIResponse.fail(e.message);
    } catch (e) {
      debugPrint('[AiService] request failed: $e');
      return AIResponse.fail('AI request failed. Please try again.');
    }
  }
}
