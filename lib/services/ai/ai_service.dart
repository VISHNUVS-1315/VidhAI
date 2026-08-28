import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_config.dart';

// ─── Request Models ──────────────────────────────────────────────────────────

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

// ─── Response Model ──────────────────────────────────────────────────────────

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

  factory AIResponse.ok(String content, {String provider = 'mock', Map<String, dynamic>? metadata}) {
    return AIResponse(
      success: true,
      content: content,
      provider: provider,
      metadata: metadata,
    );
  }

  factory AIResponse.fail(String error, {String provider = 'mock'}) {
    return AIResponse(
      success: false,
      content: '',
      provider: provider,
      error: error,
    );
  }

  Map<String, dynamic> toMap() => {
        'success': success,
        'content': content,
        'provider': provider,
        if (metadata != null) 'metadata': metadata,
        if (error != null) 'error': error,
      };

  /// Convenience: parse content as JSON map
  Map<String, dynamic>? get jsonContent {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ─── AI Service ──────────────────────────────────────────────────────────────

class AiService {
  AiService._();
  static final AiService _instance = AiService._();
  static AiService get instance => _instance;

  AIConfig _config = AIConfig.defaultConfig;
  AIConfig get config => _config;

  void configure(AIConfig config) {
    _config = config;
  }

  /// Load configuration from Firestore `config/ai` document.
  /// Falls back to mock if the document doesn't exist or read fails.
  Future<void> loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.doc('config/ai').get();
      if (doc.exists && doc.data() != null) {
        _config = AIConfig.fromMap(doc.data()!);
      }
    } catch (_) {
      _config = AIConfig.defaultConfig;
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<AIResponse> chat(String message, {String? language, Map<String, dynamic>? context}) async {
    switch (_config.provider) {
      case AIProvider.mock:
        return _mockChat(message, language: language);
      case AIProvider.backend:
        return _proxyChat(message, language: language, context: context);
      case AIProvider.openai:
        return _openAIChat(message, language: language);
      case AIProvider.gemini:
        return _geminiChat(message, language: language);
      case AIProvider.ollama:
        return _proxyChat(message, language: language, context: context);
    }
  }

  // ── Crop Analysis ──────────────────────────────────────────────────────────

  Future<AIResponse> analyzeCrop(CropAnalysisRequest request) async {
    switch (_config.provider) {
      case AIProvider.mock:
        return _mockCropAnalysis(request);
      case AIProvider.backend:
        return _proxyPost('/ai/crop-analysis', request.toMap());
      case AIProvider.openai:
      case AIProvider.gemini:
      case AIProvider.ollama:
        return _proxyPost('/ai/crop-analysis', request.toMap());
    }
  }

  // ── Pest Detection ─────────────────────────────────────────────────────────

  Future<AIResponse> detectPest(PestDetectionRequest request) async {
    switch (_config.provider) {
      case AIProvider.mock:
        return _mockPestDetection(request);
      case AIProvider.backend:
        return _proxyPost('/ai/pest-detection', request.toMap());
      case AIProvider.openai:
      case AIProvider.gemini:
      case AIProvider.ollama:
        return _geminiGenerate(
          'You are VidhAI, an expert Indian agriculture pest detection specialist. '
          'Analyze this pest/disease report for crop: ${request.cropName}\n'
          '${request.symptoms != null ? 'Symptoms: ${request.symptoms}\n' : ''}'
          '${request.location != null ? 'Location: ${request.location}\n' : ''}'
          '${request.season != null ? 'Season: ${request.season}\n' : ''}'
          'Provide: 1) Pest/disease name 2) Confidence (0-100) 3) Severity (Low/Medium/High) '
          '4) Immediate treatment 5) Biological control 6) Chemical treatment (if needed) '
          '7) Prevention tips. Respond in JSON format: '
          '{"name":"...","confidence":85,"severity":"Medium","immediateTreatment":"...","biologicalControl":"...","chemicalTreatment":"...","prevention":"..."}',
        );
    }
  }

  // ── Voice Form Assist ──────────────────────────────────────────────────────

  Future<AIResponse> getVoiceFormAssist(String field, String speechInput) async {
    switch (_config.provider) {
      case AIProvider.mock:
        return _mockVoiceForm(field, speechInput);
      case AIProvider.backend:
        return _proxyPost('/ai/voice-form', {'field': field, 'speechInput': speechInput});
      case AIProvider.openai:
      case AIProvider.gemini:
      case AIProvider.ollama:
        return _proxyPost('/ai/voice-form', {'field': field, 'speechInput': speechInput});
    }
  }

  // ── Soil Analysis ──────────────────────────────────────────────────────────

  Future<AIResponse> getSoilAnalysis(SoilAnalysisRequest request) async {
    switch (_config.provider) {
      case AIProvider.mock:
        return _mockSoilAnalysis(request);
      case AIProvider.backend:
        return _proxyPost('/ai/soil-analysis', request.toMap());
      case AIProvider.openai:
      case AIProvider.gemini:
      case AIProvider.ollama:
        return _geminiGenerate(
          'You are VidhAI, an expert Indian agriculture soil scientist. '
          'Analyze this soil report:\n'
          'Soil Type: ${request.soilType}\n'
          'pH: ${request.ph}\n'
          '${request.moisture != null ? 'Moisture: ${request.moisture}\n' : ''}'
          '${request.location != null ? 'Location: ${request.location}\n' : ''}'
          'Provide: 1) Soil type confirmation 2) Characteristics 3) pH assessment '
          '4) Suitability for crops 5) Improvement recommendations. '
          'Respond in JSON format: '
          '{"soilType":"...","characteristics":"...","confidence":85,"suitability":"...","observations":"..."}',
        );
    }
  }

  // ── Daily Tasks ────────────────────────────────────────────────────────────

  Future<AIResponse> getDailyTasks(List<Map<String, dynamic>> farms) async {
    switch (_config.provider) {
      case AIProvider.mock:
        return _mockDailyTasks(farms);
      case AIProvider.backend:
        return _proxyPost('/ai/daily-tasks', {'farms': farms});
      case AIProvider.openai:
      case AIProvider.gemini:
      case AIProvider.ollama:
        return _geminiGenerate(
          'You are VidhAI, an expert Indian agriculture daily task planner. '
          'Based on these farms: ${farms.map((f) => f['farmName'] ?? 'Farm').join(', ')}\n'
          'Generate 5 prioritized daily farming tasks with: task name, description, priority (high/medium/low), '
          'estimated duration, and best time to do it. '
          'Respond in JSON format: {"tasks":[{"task":"...","description":"...","priority":"high","duration":"30 min","time":"Morning"}]}',
        );
    }
  }

  // ── Crop Recommendation ────────────────────────────────────────────────────

  Future<AIResponse> getCropRecommendation(RecommendationRequest request) async {
    switch (_config.provider) {
      case AIProvider.mock:
        return _mockCropRecommendation(request);
      case AIProvider.backend:
        return _proxyPost('/ai/crop-recommendation', request.toMap());
      case AIProvider.openai:
      case AIProvider.gemini:
      case AIProvider.ollama:
        return _geminiGenerate(
          'You are VidhAI, an expert Indian agriculture crop advisor. '
          'Based on this farm profile and questionnaire:\n${request.farmProfile}\n'
          '${request.preferences != null ? 'Preferences: ${request.preferences}\n' : ''}'
          '${request.season != null ? 'Season: ${request.season}\n' : ''}'
          '${request.location != null ? 'Location: ${request.location}\n' : ''}'
          'Recommend the top 5 best crops with: crop name, category, expected yield, '
          'market demand (high/medium/low), water requirement (high/medium/low), '
          'profitability score (1-10), risk level (low/medium/high), '
          'reasoning, and estimated days to harvest. '
          'Respond in JSON format: {"recommendations":[{"cropName":"...","category":"...","expectedYield":"...","marketDemand":"high","waterRequirement":"medium","profitabilityScore":8,"riskLevel":"low","reasoning":"...","daysToHarvest":90}]}',
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Backend Proxy Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AIResponse> _proxyChat(String message, {String? language, Map<String, dynamic>? context}) async {
    return _proxyPost('/ai/chat', {
      'message': message,
      if (language != null) 'language': language,
      if (context != null) 'context': context,
    });
  }

  Future<AIResponse> _proxyPost(String path, Map<String, dynamic> body) async {
    try {
      final url = Uri.parse('${_config.backendUrl}$path');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (_config.apiKey != null) 'Authorization': 'Bearer ${_config.apiKey}',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AIResponse(
          success: data['success'] ?? true,
          content: data['content'] ?? data['response'] ?? '',
          provider: _config.provider.name,
          metadata: data['metadata'],
        );
      } else {
        return AIResponse.fail(
          'Backend returned ${response.statusCode}',
          provider: _config.provider.name,
        );
      }
    } catch (e) {
      return AIResponse.fail(
        'Network error: ${e.toString()}',
        provider: _config.provider.name,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Direct Provider Calls (OpenAI / Gemini — future expansion)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<AIResponse> _geminiGenerate(String prompt) async {
    if (_config.apiKey == null) {
      return AIResponse.fail('Gemini API key not configured', provider: 'gemini');
    }
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${_config.apiKey}',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2048,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return AIResponse.ok(content, provider: 'gemini');
      } else {
        return AIResponse.fail('Gemini error ${response.statusCode}', provider: 'gemini');
      }
    } catch (e) {
      return AIResponse.fail('Gemini request failed: ${e.toString()}', provider: 'gemini');
    }
  }

  Future<AIResponse> _openAIChat(String message, {String? language}) async {
    if (_config.apiKey == null) {
      return AIResponse.fail('OpenAI API key not configured', provider: 'openai');
    }
    try {
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_config.apiKey}',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are VidhAI, an expert Indian agriculture assistant. '
                      'Respond in ${language ?? 'English'}. '
                      'Be concise, practical, and region-specific.',
            },
            {'role': 'user', 'content': message},
          ],
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return AIResponse.ok(content, provider: 'openai');
      } else {
        return AIResponse.fail('OpenAI error ${response.statusCode}', provider: 'openai');
      }
    } catch (e) {
      return AIResponse.fail('OpenAI request failed: ${e.toString()}', provider: 'openai');
    }
  }

  Future<AIResponse> _geminiChat(String message, {String? language}) async {
    if (_config.apiKey == null) {
      return AIResponse.fail('Gemini API key not configured', provider: 'gemini');
    }
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${_config.apiKey}',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'You are VidhAI, an expert Indian agriculture assistant. '
                          'Respond in ${language ?? 'English'}. '
                          'Be concise, practical, and region-specific.\n\n'
                          '$message',
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        return AIResponse.ok(content, provider: 'gemini');
      } else {
        return AIResponse.fail('Gemini error ${response.statusCode}', provider: 'gemini');
      }
    } catch (e) {
      return AIResponse.fail('Gemini request failed: ${e.toString()}', provider: 'gemini');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mock Responses — Contextually Relevant & Structured
  // ═══════════════════════════════════════════════════════════════════════════

  AIResponse _mockChat(String message, {String? language}) {
    final lower = message.toLowerCase();
    String response;

    if (lower.contains('water') || lower.contains('irrigat')) {
      response = jsonEncode({
        'answer': 'Water Management Tips for Indian Farms',
        'details': [
          'Water your crops early morning (6–8 AM) or evening (5–7 PM) to minimize evaporation.',
          'Drip irrigation can save 30–50% water compared to flood irrigation.',
          'For paddy fields, maintain 5 cm standing water during vegetative stage.',
          'Mulching with straw or plastic reduces water loss by 25–30%.',
          'Check soil moisture at 15 cm depth — if dry, it is time to irrigate.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('fertilis') || lower.contains('fertil') || lower.contains('nutrient')) {
      response = jsonEncode({
        'answer': 'Fertilizer Recommendation',
        'details': [
          'For most cereal crops, use NPK ratio of 4:2:1 (Nitrogen:Phosphorus:Potassium).',
          'Apply urea in 2–3 split doses rather than a single application.',
          'For pulses, use Rhizobium inoculant to enhance nitrogen fixation.',
          'Soil testing every season is critical — do not guess nutrient levels.',
          'Vermicompost at 2–3 tonnes/hectare improves soil structure significantly.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('pest') || lower.contains('insect') || lower.contains('disease')) {
      response = jsonEncode({
        'answer': 'Pest & Disease Management Overview',
        'details': [
          'Follow IPM (Integrated Pest Management) — start with cultural practices.',
          'Neem oil spray (5 ml/L) is effective against most sucking pests.',
          'Yellow sticky traps help monitor and reduce whitefly populations.',
          'Rotate crops annually to break pest and disease cycles.',
          'Consult your nearest KVK for region-specific pest alerts.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('soil')) {
      response = jsonEncode({
        'answer': 'Soil Health Guidelines',
        'details': [
          'Ideal soil pH for most crops: 6.0–7.5.',
          'Add organic matter (FYM/compost) annually to improve soil biology.',
          'Get a Soil Health Card from your nearest testing lab.',
          'Avoid excessive tillage — it damages soil structure and kills earthworms.',
          'Green manuring with dhaincha or sunnhemp adds 60–80 kg N/hectare.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('weather') || lower.contains('rain') || lower.contains('monsoon')) {
      response = jsonEncode({
        'answer': 'Weather & Seasonal Advisory',
        'details': [
          'Check IMD (India Meteorological Department) forecasts regularly.',
          'Before monsoon: ensure field drainage channels are clear.',
          'During drought: prioritize irrigation for crops at critical growth stages.',
          'Post-rain: watch for fungal infections — apply preventive fungicide if needed.',
          'Store harvested produce in dry, ventilated areas during humid seasons.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('hello') || lower.contains('hi') || lower.contains('namaste')) {
      response = jsonEncode({
        'answer': 'Namaste! I am VidhAI, your smart farming assistant.',
        'details': [
          'I can help you with crop management, pest control, soil health, and more.',
          'Try asking about: irrigation, fertilizers, pest control, or crop recommendations.',
          'I support multiple Indian languages — just ask in your preferred language.',
          'Upload a photo of your crop for AI-powered analysis.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else {
      response = jsonEncode({
        'answer': 'VidhAI Response',
        'details': [
          'I understand your query: "$message"',
          'For the most accurate advice, try providing more details like your crop type, location, and current observations.',
          'You can ask me about: crops, soil, irrigation, fertilizers, pests, weather, or market prices.',
          'Remember: local conditions matter — consult your KVK or agricultural officer for region-specific guidance.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    }

    return AIResponse.ok(response, provider: 'mock');
  }

  AIResponse _mockCropAnalysis(CropAnalysisRequest request) {
    final analysis = jsonEncode({
      'cropName': request.cropName,
      'growthStage': request.growthStage ?? 'Not specified',
      'analysis': {
        'healthScore': 78,
        'healthRating': 'Good',
        'observations': [
          '${request.cropName} shows normal vegetative growth patterns.',
          'Leaf color appears healthy green — no visible nutrient deficiency.',
          'Growth stage is consistent with expected timeline.',
          'Canopy coverage is adequate for this stage.',
        ],
        'recommendations': [
          'Continue regular irrigation schedule — 1 irrigation per week.',
          'Monitor for early signs of pest infestation during this growth stage.',
          'Consider applying balanced NPK fertilizer at recommended dosage.',
          'Ensure proper spacing between plants for air circulation.',
        ],
        'warnings': [
          'Watch for leaf spot symptoms if humidity is high.',
          'Ensure drainage is adequate before expected rainfall.',
        ],
        'nextReviewDate': '2026-09-02',
      },
      'source': 'VidhAI Mock Engine — Upload actual images for AI vision analysis',
    });
    return AIResponse.ok(analysis, provider: 'mock');
  }

  AIResponse _mockPestDetection(PestDetectionRequest request) {
    final detection = jsonEncode({
      'cropName': request.cropName,
      'detectedIssue': 'Potential Aphid Infestation (Common in ${request.cropName})',
      'severity': 'Moderate',
      'severityScore': 5,
      'confidence': 0.72,
      'description': 'Aphids are small sap-sucking insects that commonly attack ${request.cropName}. '
          'They cluster on the underside of leaves and tender shoots, causing leaf curling and stunted growth.',
      'treatment': {
        'immediate': [
          'Spray neem oil solution (5 ml neem oil + 2 ml liquid soap per litre of water).',
          'Remove heavily infested plant parts and destroy them.',
          'Spray in the evening to avoid harming beneficial insects.',
        ],
        'biological': [
          'Release ladybugs (natural predator of aphids) in the field.',
          'Encourage presence of lacewings and parasitic wasps.',
          'Use yellow sticky traps to monitor and reduce population.',
        ],
        'chemical': [
          'If severe: Imidacloprid 17.8 SL @ 0.3 ml/L water.',
          'Alternate with Flonicamid 50% WG @ 0.3 g/L for resistance management.',
          'Always follow recommended dosage and pre-harvest interval.',
        ],
      },
      'prevention': [
        'Regular scouting of crops, especially undersides of leaves.',
        'Maintain balanced nitrogen fertilization — excess N attracts aphids.',
        'Use resistant/tolerant varieties where available.',
        'Keep field margins clean to reduce pest harbourage.',
      ],
      'source': 'VidhAI Mock Engine — Upload images for precise AI-powered identification',
    });
    return AIResponse.ok(detection, provider: 'mock');
  }

  AIResponse _mockVoiceForm(String field, String speechInput) {
    String extracted;
    Map<String, dynamic> metadata = {};

    final lower = speechInput.toLowerCase().trim();

    if (field.toLowerCase().contains('area') || field.toLowerCase().contains('acre') || field.toLowerCase().contains('hectare')) {
      extracted = _extractNumber(lower) ?? '2.5';
      metadata = {'unit': 'acres', 'confidence': 0.85, 'originalInput': speechInput};
    } else if (field.toLowerCase().contains('crop') || field.toLowerCase().contains('name')) {
      final crops = ['rice', 'wheat', 'cotton', 'sugarcane', 'maize', 'tomato', 'potato', 'onion', 'chilli', 'groundnut'];
      extracted = crops.firstWhere(
        (c) => lower.contains(c),
        orElse: () => speechInput,
      );
      metadata = {'field': 'cropName', 'confidence': 0.9, 'originalInput': speechInput};
    } else if (field.toLowerCase().contains('date') || field.toLowerCase().contains('day')) {
      extracted = _extractDate(lower) ?? '2026-08-26';
      metadata = {'field': 'date', 'confidence': 0.8, 'originalInput': speechInput};
    } else if (field.toLowerCase().contains('phone') || field.toLowerCase().contains('mobile')) {
      extracted = RegExp(r'\d{10}').firstMatch(lower)?.group(0) ?? speechInput.replaceAll(RegExp(r'[^0-9]'), '');
      metadata = {'field': 'phone', 'confidence': 0.7, 'originalInput': speechInput};
    } else {
      extracted = speechInput;
      metadata = {'field': field, 'confidence': 0.6, 'originalInput': speechInput, 'note': 'Could not determine specific extraction pattern'};
    }

    final result = jsonEncode({
      'extractedValue': extracted,
      'originalInput': speechInput,
      'field': field,
      'metadata': metadata,
      'source': 'VidhAI Mock Engine',
    });
    return AIResponse.ok(result, provider: 'mock');
  }

  String? _extractNumber(String text) {
    final patterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:acre|acres)'),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:hectare|hectares|ha)'),
      RegExp(r'(\d+(?:\.\d+)?)'),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _extractDate(String text) {
    final match = RegExp(r'(\d{1,2})\s*(?:st|nd|rd|th)?\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*').firstMatch(text);
    if (match != null) {
      final months = {
        'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
        'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
        'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
      };
      final day = match.group(1)!.padLeft(2, '0');
      final month = months[match.group(2)!.toLowerCase().substring(0, 3)] ?? '01';
      return '2026-$month-$day';
    }
    return null;
  }

  AIResponse _mockSoilAnalysis(SoilAnalysisRequest request) {
    final phValue = double.tryParse(request.ph) ?? 7.0;
    String phStatus;
    if (phValue < 5.5) {
      phStatus = 'Strongly Acidic — Needs immediate lime application';
    } else if (phValue < 6.5) {
      phStatus = 'Slightly Acidic — Acceptable for most crops, consider liming';
    } else if (phValue <= 7.5) {
      phStatus = 'Neutral — Ideal for most crops';
    } else if (phValue <= 8.5) {
      phStatus = 'Slightly Alkaline — May cause micronutrient deficiency';
    } else {
      phStatus = 'Strongly Alkaline — Needs gypsum/sulphur amendment';
    }

    final healthScore = _phToScore(phValue);

    final analysis = jsonEncode({
      'soilType': request.soilType,
      'ph': request.ph,
      'phStatus': phStatus,
      'moisture': request.moisture ?? 'Not measured',
      'healthScore': healthScore,
      'healthRating': healthScore >= 80
          ? 'Excellent'
          : healthScore >= 60
              ? 'Good'
              : healthScore >= 40
                  ? 'Fair'
                  : 'Poor',
      'nutrientEstimate': {
        'nitrogen': healthScore >= 70 ? 'Adequate' : 'May need supplementation',
        'phosphorus': phValue >= 6.0 ? 'Likely adequate' : 'May be locked — apply rock phosphate',
        'potassium': 'Test recommended for accurate assessment',
        'organicMatter': request.soilType.toLowerCase().contains('black') ? 'Typically good in black cotton soil' : 'Add FYM to improve',
      },
      'recommendations': [
        if (phValue < 6.0) 'Apply agricultural lime at 2–4 tonnes/hectare to raise pH.',
        if (phValue > 8.0) 'Apply gypsum at 2–3 tonnes/hectare to lower pH.',
        'Add 10–15 tonnes/hectare of farmyard manure (FYM) annually.',
        'Practice crop rotation with legumes to naturally fix nitrogen.',
        'Get a complete Soil Health Card analysis for precise nutrient data.',
        'Consider green manuring with dhaincha or sunnhemp.',
      ],
      'suitableCrops': _cropsForSoil(request.soilType, phValue),
      'source': 'VidhAI Mock Engine',
    });
    return AIResponse.ok(analysis, provider: 'mock');
  }

  int _phToScore(double ph) {
    if (ph >= 6.0 && ph <= 7.5) return 88;
    if (ph >= 5.5 && ph <= 8.0) return 72;
    if (ph >= 5.0 && ph <= 8.5) return 55;
    return 35;
  }

  List<String> _cropsForSoil(String soilType, double ph) {
    final lower = soilType.toLowerCase();
    if (lower.contains('black') || lower.contains('vertisol')) {
      return ['Cotton', 'Soybean', 'Chickpea', 'Sorghum', 'Pigeon Pea'];
    } else if (lower.contains('red') || lower.contains('alfisol')) {
      return ['Groundnut', 'Maize', 'Sunflower', 'Cotton', 'Rice'];
    } else if (lower.contains('alluvial') || lower.contains('entisol')) {
      return ['Rice', 'Wheat', 'Sugarcane', 'Potato', 'Mustard'];
    } else if (lower.contains('laterite') || lower.contains('oxisol')) {
      return ['Tea', 'Coffee', 'Rubber', 'Cashew', 'Rice'];
    } else if (lower.contains('sandy') || lower.contains('aridisol')) {
      return ['Watermelon', 'Groundnut', 'Cactus', 'Bajra', 'Guar'];
    }
    return ['Rice', 'Wheat', 'Maize', 'Pulses', 'Vegetables'];
  }

  AIResponse _mockDailyTasks(List<Map<String, dynamic>> farms) {
    final List<Map<String, dynamic>> tasks = [];

    for (final farm in farms) {
      final farmName = farm['name'] ?? 'Farm';
      final crops = (farm['crops'] as List<dynamic>?) ?? [];

      tasks.add({
        'farmName': farmName,
        'tasks': [
          {
            'id': 't1_${farmName.hashCode}',
            'title': 'Morning field inspection',
            'description': 'Walk through $farmName and check for any visible pest damage, wilting, or unusual growth patterns.',
            'category': 'inspection',
            'priority': 'high',
            'estimatedTime': '30 min',
            'timeWindow': '6:00 AM – 8:00 AM',
          },
          {
            'id': 't2_${farmName.hashCode}',
            'title': 'Irrigation check',
            'description': 'Check soil moisture at 15 cm depth. Irrigate if soil is dry to touch. Ensure all drip/sprinkler systems are functioning.',
            'category': 'irrigation',
            'priority': crops.isNotEmpty ? 'high' : 'medium',
            'estimatedTime': '45 min',
            'timeWindow': '6:00 AM – 9:00 AM',
          },
          {
            'id': 't3_${farmName.hashCode}',
            'title': 'Weed management',
            'description': 'Remove weeds from field borders and between crop rows. Prioritize areas near water channels.',
            'category': 'maintenance',
            'priority': 'medium',
            'estimatedTime': '1 hour',
            'timeWindow': '7:00 AM – 10:00 AM',
          },
          if (crops.isNotEmpty)
            {
              'id': 't4_${farmName.hashCode}',
              'title': 'Crop health monitoring — ${crops.join(", ")}',
              'description': 'Inspect ${crops.join(" and ")} for signs of pest infestation, nutrient deficiency, or disease. Take photos for AI analysis.',
              'category': 'monitoring',
              'priority': 'high',
              'estimatedTime': '30 min',
              'timeWindow': '7:00 AM – 9:00 AM',
            },
          {
            'id': 't5_${farmName.hashCode}',
            'title': 'Record keeping',
            'description': 'Update farm diary: note any observations, input usage, and weather conditions for today.',
            'category': 'documentation',
            'priority': 'low',
            'estimatedTime': '15 min',
            'timeWindow': 'Anytime',
          },
        ],
      });
    }

    if (farms.isEmpty) {
      tasks.add({
        'farmName': 'General',
        'tasks': [
          {
            'id': 't1_gen',
            'title': 'Add your farms to get personalized tasks',
            'description': 'Go to Farm Settings and add your farm details to receive AI-generated daily tasks.',
            'category': 'setup',
            'priority': 'medium',
            'estimatedTime': '5 min',
            'timeWindow': 'Anytime',
          },
        ],
      });
    }

    final result = jsonEncode({
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'farmCount': farms.length,
      'totalTasks': tasks.fold<int>(0, (sumTotal, farm) => sumTotal + ((farm['tasks'] as List).length)),
      'farmTasks': tasks,
      'source': 'VidhAI Mock Engine',
    });
    return AIResponse.ok(result, provider: 'mock');
  }

  AIResponse _mockCropRecommendation(RecommendationRequest request) {
    final farmProfile = request.farmProfile;
    final soilType = (farmProfile['soilType'] ?? 'alluvial').toString().toLowerCase();
    final area = farmProfile['area'] ?? 5;
    final season = request.season ?? 'kharif';

    final List<Map<String, dynamic>> recommendations = [];

    if (season.toLowerCase() == 'kharif') {
      recommendations.addAll([
        {
          'crop': 'Rice (Dhan)',
          'suitabilityScore': 92,
          'expectedYield': '4–6 tonnes/hectare',
          'waterRequirement': 'High (1200–1500 mm)',
          'investmentLevel': 'Medium',
          'reasoning': 'Excellent match for $soilType soil during Kharif season. High market demand.',
          'riskLevel': 'Low',
          'marketPrice': '₹2,183/quintal (MSP)',
        },
        {
          'crop': 'Cotton (Kapas)',
          'suitabilityScore': 85,
          'expectedYield': '20–25 quintals/hectare',
          'waterRequirement': 'Medium (700–1300 mm)',
          'investmentLevel': 'High',
          'reasoning': 'Good returns if Bt cotton variety is used. Requires careful pest management.',
          'riskLevel': 'Medium',
          'marketPrice': '₹6,620/quintal (MSP)',
        },
        {
          'crop': 'Soybean',
          'suitabilityScore': 80,
          'expectedYield': '1.2–1.5 tonnes/hectare',
          'waterRequirement': 'Medium (450–650 mm)',
          'investmentLevel': 'Low',
          'reasoning': 'Low-cost crop with good nitrogen fixation. Good rotation crop.',
          'riskLevel': 'Medium',
          'marketPrice': '₹4,300/quintal (MSP)',
        },
        {
          'crop': 'Maize (Makka)',
          'suitabilityScore': 75,
          'expectedYield': '5–8 tonnes/hectare',
          'waterRequirement': 'Medium (500–800 mm)',
          'investmentLevel': 'Medium',
          'reasoning': 'Versatile crop with multiple market options (food, feed, industrial).',
          'riskLevel': 'Low',
          'marketPrice': '₹1,870/quintal (MSP)',
        },
        {
          'crop': 'Groundnut (Moongphali)',
          'suitabilityScore': 70,
          'expectedYield': '1.5–2.5 tonnes/hectare',
          'waterRequirement': 'Low–Medium (400–600 mm)',
          'investmentLevel': 'Low',
          'reasoning': 'Good oilseed option. Fixes nitrogen and improves soil health.',
          'riskLevel': 'Low',
          'marketPrice': '₹5,550/quintal (MSP)',
        },
      ]);
    } else {
      recommendations.addAll([
        {
          'crop': 'Wheat (Gehu)',
          'suitabilityScore': 94,
          'expectedYield': '4–5 tonnes/hectare',
          'waterRequirement': 'Medium (450–650 mm)',
          'investmentLevel': 'Medium',
          'reasoning': 'Primary Rabi crop with assured MSP procurement. Excellent for $soilType soil.',
          'riskLevel': 'Low',
          'marketPrice': '₹2,275/quintal (MSP)',
        },
        {
          'crop': 'Mustard (Sarson)',
          'suitabilityScore': 82,
          'expectedYield': '1.2–1.8 tonnes/hectare',
          'waterRequirement': 'Low (350–500 mm)',
          'investmentLevel': 'Low',
          'reasoning': 'Excellent oilseed for Rabi season. Low water requirement.',
          'riskLevel': 'Low',
          'marketPrice': '₹5,450/quintal (MSP)',
        },
        {
          'crop': 'Chickpea (Chana)',
          'suitabilityScore': 80,
          'expectedYield': '1.5–2.0 tonnes/hectare',
          'waterRequirement': 'Low (300–400 mm)',
          'investmentLevel': 'Low',
          'reasoning': 'High-protein pulse. Fixes atmospheric nitrogen. Very low water needs.',
          'riskLevel': 'Low',
          'marketPrice': '₹5,230/quintal (MSP)',
        },
        {
          'crop': 'Potato (Aloo)',
          'suitabilityScore': 75,
          'expectedYield': '20–30 tonnes/hectare',
          'waterRequirement': 'Medium (500–700 mm)',
          'investmentLevel': 'Medium–High',
          'reasoning': 'High-value crop with strong market demand. Requires good drainage.',
          'riskLevel': 'Medium',
          'marketPrice': 'Market-linked',
        },
        {
          'crop': 'Peas (Matar)',
          'suitabilityScore': 72,
          'expectedYield': '1.0–1.5 tonnes/hectare',
          'waterRequirement': 'Low (300–400 mm)',
          'investmentLevel': 'Low',
          'reasoning': 'Good pulse crop. Improves soil fertility through nitrogen fixation.',
          'riskLevel': 'Low',
          'marketPrice': 'Market-linked',
        },
      ]);
    }

    final result = jsonEncode({
      'season': season,
      'farmArea': '$area acres',
      'soilType': farmProfile['soilType'] ?? 'Not specified',
      'recommendations': recommendations,
      'disclaimer': 'These are general recommendations. Consult your local KVK for region-specific advice.',
      'source': 'VidhAI Mock Engine',
    });
    return AIResponse.ok(result, provider: 'mock');
  }
}
