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

  factory AIResponse.ok(String content,
      {String provider = 'mock', Map<String, dynamic>? metadata}) {
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
        final loaded = AIConfig.fromMap(doc.data()!);
        // Only apply if the stored config is not a downgrade to mock — the
        // no-fake-data policy requires the backend to be the real default.
        if (!loaded.isMock) {
          _config = loaded;
        }
      }
    } catch (_) {
      // Keep the current config (main.dart sets backend); never silently
      // downgrade to mock when Firestore read fails.
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<AIResponse> chat(String message,
      {String? language, Map<String, dynamic>? context}) async {
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

  Future<AIResponse> getVoiceFormAssist(
      String field, String speechInput) async {
    switch (_config.provider) {
      case AIProvider.mock:
        return _mockVoiceForm(field, speechInput);
      case AIProvider.backend:
        return _proxyPost(
            '/ai/voice-form', {'field': field, 'speechInput': speechInput});
      case AIProvider.openai:
      case AIProvider.gemini:
      case AIProvider.ollama:
        return _proxyPost(
            '/ai/voice-form', {'field': field, 'speechInput': speechInput});
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

  Future<AIResponse> getCropRecommendation(
      RecommendationRequest request) async {
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

  Future<AIResponse> _proxyChat(String message,
      {String? language, Map<String, dynamic>? context}) async {
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
          if (_config.apiKey != null)
            'Authorization': 'Bearer ${_config.apiKey}',
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
      return AIResponse.fail('Gemini API key not configured',
          provider: 'gemini');
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
        final content =
            data['candidates'][0]['content']['parts'][0]['text'] as String;
        return AIResponse.ok(content, provider: 'gemini');
      } else {
        return AIResponse.fail('Gemini error ${response.statusCode}',
            provider: 'gemini');
      }
    } catch (e) {
      return AIResponse.fail('Gemini request failed: ${e.toString()}',
          provider: 'gemini');
    }
  }

  Future<AIResponse> _openAIChat(String message, {String? language}) async {
    if (_config.apiKey == null) {
      return AIResponse.fail('OpenAI API key not configured',
          provider: 'openai');
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
        return AIResponse.fail('OpenAI error ${response.statusCode}',
            provider: 'openai');
      }
    } catch (e) {
      return AIResponse.fail('OpenAI request failed: ${e.toString()}',
          provider: 'openai');
    }
  }

  Future<AIResponse> _geminiChat(String message, {String? language}) async {
    if (_config.apiKey == null) {
      return AIResponse.fail('Gemini API key not configured',
          provider: 'gemini');
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
        return AIResponse.fail('Gemini error ${response.statusCode}',
            provider: 'gemini');
      }
    } catch (e) {
      return AIResponse.fail('Gemini request failed: ${e.toString()}',
          provider: 'gemini');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Mock Responses — Contextually Relevant & Structured
  // ═══════════════════════════════════════════════════════════════════════════

  AIResponse _mockChat(String message, {String? language}) {
    final lower = message.toLowerCase().trim();
    String response = '';

    if (lower.contains('price') ||
        lower.contains('rate') ||
        lower.contains('cost') ||
        lower.contains('mandi') ||
        lower.contains('விலை')) {
      return _handlePriceQuery(lower);
    } else if (lower.contains('what should i do') ||
        lower.contains('what to do') ||
        lower.contains('now') && lower.contains('do') ||
        lower.contains('today')) {
      response = jsonEncode({
        'answer': 'Here is your quick action plan for today',
        'details': [
          'Walk your field early (5–7 AM) and check leaves for pests, yellowing or wilting.',
          'Check soil moisture at 15 cm depth — irrigate only if dry to the touch.',
          'Water early morning or evening to reduce evaporation loss.',
          'Look up today’s mandi price for your crop before deciding where to sell.',
          'Note observations in your farm records so patterns become visible over time.',
          'If you suspect a pest, upload a leaf photo or describe the symptoms for analysis.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('best crop') ||
        lower.contains('which crop') ||
        lower.contains('what to grow') ||
        lower.contains('recommend crop') ||
        lower.contains('crop suggest')) {
      final month = DateTime.now().month;
      final season = (month >= 6 && month <= 10)
          ? 'Kharif (June–October)'
          : (month >= 11 || month <= 2)
              ? 'Rabi (November–March)'
              : 'Zaid (April–May)';
      response = jsonEncode({
        'answer': 'Recommended crops for the current season — $season',
        'details': [
          'Rice (Paddy): high demand, assured MSP, protein-rich staple. Low risk.',
          'Maize: versatile, used for food, feed and industry. Low risk.',
          'Chickpea & pulses: low input cost, fixes nitrogen, improves soil.',
          'Tomato / Chilli (vegetables): quick returns, high market demand.',
          'Mustard / Groundnut (oilseeds): good for rabi or dryland areas.',
          'For a personalised list, share your soil type, state and available water.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('water') || lower.contains('irrigat')) {
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
    } else if (lower.contains('fertil') ||
        lower.contains('nutrient') ||
        lower.contains('urea') ||
        lower.contains('npk')) {
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
    } else if (lower.contains('pest') ||
        lower.contains('insect') ||
        lower.contains('disease') ||
        lower.contains('fungal') ||
        lower.contains('aphid') ||
        lower.contains('borer')) {
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
    } else if (lower.contains('weather') ||
        lower.contains('rain') ||
        lower.contains('monsoon') ||
        lower.contains('forecast')) {
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
    } else if (lower.contains('sow') ||
        lower.contains('planting') ||
        lower.contains('seed')) {
      response = jsonEncode({
        'answer': 'Sowing & Planting Advice',
        'details': [
          'Time sowing to the first monsoonal rains for rain-fed crops.',
          'Soak and treat seeds with fungicide before sowing to prevent early diseases.',
          'Maintain proper seed spacing — overcrowding reduces yield.',
          'Test germination rate of saved seed before the season.',
          'Use certified/improved varieties from your nearest seed centre for better yield.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('harvest')) {
      response = jsonEncode({
        'answer': 'Harvesting Guidance',
        'details': [
          'Harvest at the right maturity — check grain hardness and moisture (below 14%).',
          'Harvest early morning or late afternoon to reduce moisture content.',
          'Dry produce thoroughly on clean, raised surfaces before storage.',
          'Grade your produce to get a better mandi price.',
          'Book transport early during peak harvest to avoid delays.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('scheme') ||
        lower.contains('subsidy') ||
        lower.contains('kisan') ||
        lower.contains('pm')) {
      response = jsonEncode({
        'answer': 'Government Schemes You May Qualify For',
        'details': [
          'PM-KISAN: ₹6,000/year income support for landholding farmers.',
          'PMFBY: Crop insurance with low premium under Pradhan Mantri Fasal Bima Yojana.',
          'Kisan Credit Card (KCC): low-interest credit for inputs.',
          'Soil Health Card scheme: free soil testing and guidance.',
          'Visit your block development office or PM-KISAN portal to check eligibility.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('tomato') ||
        lower.contains('rice') ||
        lower.contains('wheat') ||
        lower.contains('chilli') ||
        lower.contains('onion') ||
        lower.contains('potato') ||
        lower.contains('cotton') ||
        lower.contains('maize') ||
        lower.contains('sugarcane') ||
        lower.contains('chickpea') ||
        lower.contains('gram') ||
        lower.contains('mustard')) {
      if (!lower.contains('price') &&
          !lower.contains('rate') &&
          !lower.contains('cost')) {
        final cropRegex = RegExp(
            '\\b(tomato|rice|wheat|chilli|onion|potato|potatoes|onions|cotton|maize|sugarcane|chickpea|gram|mustard)\\b');
        if (cropRegex.hasMatch(lower)) {
          return _handleCropAdvisory(lower, message);
        }
      }
    } else if (lower.contains('crop') ||
        lower.contains('grow') ||
        lower.contains('cultivate')) {
      response = jsonEncode({
        'answer': 'Crop cultivation guidance',
        'details': [
          'Tell me which crop you are interested in — e.g. tomato, rice, wheat, onion, chilli.',
          'Share your state and soil type for region-specific planting advice.',
          'I can also check the current season’s best crops or recommend alternatives.',
          'For exact yield and investment figures, use the Crop Recommendation tool.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else if (lower.contains('hello') ||
        lower.contains('hi') ||
        lower.contains('namaste') ||
        lower.contains('vanakkam') ||
        lower.contains('good morning') ||
        lower.contains('good evening')) {
      response = jsonEncode({
        'answer': 'Namaste! I am VidhAI, your smart farming assistant.',
        'details': [
          'I can help you with crop management, pest control, soil health, and more.',
          'Try asking about: mandi prices, irrigation, fertilizers, pest control, or crop recommendations.',
          'I support multiple Indian languages — just ask in your preferred language.',
          'You can also upload a photo of your crop for AI-powered analysis.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    } else {
      response = jsonEncode({
        'answer': 'Here is how I can help with “$message”',
        'details': [
          'To give precise advice, please tell me your crop, state and current field condition.',
          'I can help with: mandi prices, irrigation, fertilizers, pest & disease control, soil health, weather, sowing, harvesting and government schemes.',
          'For a fast pest diagnosis, upload a clear photo of the affected leaf.',
          'Local conditions matter — always confirm region-specific guidance with your KVK or agriculture officer.',
        ],
        'source': 'VidhAI Mock Engine',
      });
    }

    return AIResponse.ok(response, provider: 'mock');
  }

  /// Shared crop advisory for known crops
  AIResponse _handleCropAdvisory(String lower, String original) {
    final Map<String, Map<String, String>> crops = {
      'tomato': {
        'name': 'Tomato',
        'info':
            'Grows best at 20–30°C in loamy soil. Expect 20–30 quintals/acre with good care.',
        'care':
            'Stake plants, prune suckers, remove yellow leaves, and water regularly.',
      },
      'rice': {
        'name': 'Rice / Paddy',
        'info':
            'Needs high, standing water (1200–1500 mm). 120–150 day crop, high MSP demand.',
        'care':
            'Maintain 5 cm water in vegetative stage; watch for stem borer and blast.',
      },
      'wheat': {
        'name': 'Wheat',
        'info':
            'Rabi crop, best at 10–25°C in loamy soil. 18–25 quintals/acre expected.',
        'care':
            'Regular light irrigation; watch for yellow rust in humid spells.',
      },
      'chilli': {
        'name': 'Chilli',
        'info':
            'Warm season crop, 20–35°C. High-value spice with strong market demand.',
        'care': 'Avoid overwatering; watch for fruit borer and powdery mildew.',
      },
      'onion': {
        'name': 'Onion',
        'info':
            'Rabi crop with good storage value. 15–25 quintals/acre expected.',
        'care':
            'Well-drained loamy soil; reduce water as bulbs mature to aid curing.',
      },
      'potato': {
        'name': 'Potato',
        'info':
            'Best at 15–25°C in sandy loam. High yield of 80–120 quintals/acre.',
        'care':
            'Ensure good drainage; watch for late blight in cool, wet weather.',
      },
      'cotton': {
        'name': 'Cotton / Kapas',
        'info': 'Good returns with Bt varieties; 20–25 quintals/acre.',
        'care':
            'Protect from bollworm and sucking pests; manage water carefully.',
      },
      'maize': {
        'name': 'Maize',
        'info': 'Versatile crop, 5–8 tonnes/acre, many market uses.',
        'care': 'Fertile, well-drained soil; watch for stem borer.',
      },
      'sugarcane': {
        'name': 'Sugarcane',
        'info': 'Long-duration, high-water crop. Strong industrial demand.',
        'care': 'Ridges and furrows for drainage; control weeds early.',
      },
      'chickpea': {
        'name': 'Chickpea / Chana',
        'info': 'Rabi pulse, low water, fixes nitrogen. 8–12 quintals/acre.',
        'care': 'Well-drained loam; avoid waterlogging during pod filling.',
      },
      'gram': {
        'name': 'Chickpea / Gram',
        'info': 'Rabi pulse, low water, fixes nitrogen. 8–12 quintals/acre.',
        'care': 'Well-drained loam; avoid waterlogging during pod filling.',
      },
      'mustard': {
        'name': 'Mustard',
        'info': 'Rabi oilseed, low water (350–500 mm). 6–10 quintals/acre.',
        'care': 'Sow by October; watch for aphids during flowering.',
      },
    };

    Map<String, String>? chosen;
    for (final entry in crops.entries) {
      if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lower)) {
        chosen = entry.value;
        break;
      }
    }
    final name = chosen?['name'] ?? original;

    return AIResponse.ok(
        jsonEncode({
          'answer': '$name — farming guide',
          'details': [
            chosen?['info'] ??
                'Choose well-matched varieties and follow good agronomic practices.',
            chosen?['care'] ??
                'Monitor regularly for pests, disease and nutrient stress.',
            'Best planting months and yields vary by region — share your state for precision advice.',
            'For disease detection, upload a leaf photo or call it out in the Pest Detection tool.',
          ],
          'source': 'VidhAI Mock Engine',
        }),
        provider: 'mock');
  }

  /// Indicative market prices for common commodities.
  AIResponse _handlePriceQuery(String lower) {
    final Map<String, String> priceMap = {
      'rice': '₹2,180–2,400 / quintal (grade-dependent)',
      'paddy': '₹2,180–2,400 / quintal (grade-dependent)',
      'wheat': '₹2,275–2,500 / quintal',
      'maize': '₹1,870–2,100 / quintal',
      'tomato': '₹28–45 / kg (seasonal, rises in lean months)',
      'potato': '₹18–30 / kg',
      'onion': '₹32–55 / kg',
      'chilli': '₹55–90 / kg (dry chilli much higher)',
      'cotton': '₹6,620–7,500 / quintal (kapas)',
      'sugarcane': '₹340–380 / quintal (as per FRP)',
      'chickpea': '₹5,230–5,700 / quintal',
      'gram': '₹5,230–5,700 / quintal',
      'mustard': '₹5,450–5,900 / quintal',
      'groundnut': '₹5,550–6,200 / quintal',
      'soybean': '₹4,300–4,800 / quintal',
      'brinjal': '₹28–45 / kg',
      'mango': '₹30–80 / kg (variety & season)',
      'banana': '₹30–55 / dozen',
      'onions': '₹32–55 / kg',
      'tomatoes': '₹28–45 / kg (seasonal)',
      'carrot': '₹35–60 / kg',
      'cabbage': '₹12–25 / kg',
      'cauliflower': '₹18–35 / kg',
      'ladies finger': '₹30–50 / kg',
      'okra': '₹30–50 / kg',
      'pumpkin': '₹15–30 / kg',
      'coconut': '₹15–25 / nut',
      'potatoes': '₹18–30 / kg',
    };

    String? matched;
    for (final entry in priceMap.entries) {
      if (RegExp('\\b${RegExp.escape(entry.key)}\\b').hasMatch(lower)) {
        matched = entry.value;
        break;
      }
    }

    if (matched == null) {
      return AIResponse.ok(
          jsonEncode({
            'answer': 'Market price enquiry',
            'details': [
              'Prices vary daily by mandi, grade and season.',
              'Open the Market Prices tool (updates live across states) for real figures.',
              'To check a specific crop, try “rice price”, “tomato price”, “onion rate”, etc.',
              'You can also select your crop in the Market Prices section for live data.',
            ],
            'source': 'VidhAI Mock Engine',
          }),
          provider: 'mock');
    }

    return AIResponse.ok(
        jsonEncode({
          'answer': 'Indicative market price',
          'details': [
            matched,
            'Prices are indicative and vary by mandi and grade.',
            'For the latest figure, open the Market Prices tool for live data from your state.',
          ],
          'source': 'VidhAI Mock Engine',
        }),
        provider: 'mock');
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
      'source':
          'VidhAI Mock Engine — Upload actual images for AI vision analysis',
    });
    return AIResponse.ok(analysis, provider: 'mock');
  }

  AIResponse _mockPestDetection(PestDetectionRequest request) {
    final detection = jsonEncode({
      'cropName': request.cropName,
      'detectedIssue':
          'Potential Aphid Infestation (Common in ${request.cropName})',
      'severity': 'Moderate',
      'severityScore': 5,
      'confidence': 0.72,
      'description':
          'Aphids are small sap-sucking insects that commonly attack ${request.cropName}. '
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
      'source':
          'VidhAI Mock Engine — Upload images for precise AI-powered identification',
    });
    return AIResponse.ok(detection, provider: 'mock');
  }

  AIResponse _mockVoiceForm(String field, String speechInput) {
    String extracted;
    Map<String, dynamic> metadata = {};

    final lower = speechInput.toLowerCase().trim();

    if (field.toLowerCase().contains('area') ||
        field.toLowerCase().contains('acre') ||
        field.toLowerCase().contains('hectare')) {
      extracted = _extractNumber(lower) ?? '2.5';
      metadata = {
        'unit': 'acres',
        'confidence': 0.85,
        'originalInput': speechInput
      };
    } else if (field.toLowerCase().contains('crop') ||
        field.toLowerCase().contains('name')) {
      final crops = [
        'rice',
        'wheat',
        'cotton',
        'sugarcane',
        'maize',
        'tomato',
        'potato',
        'onion',
        'chilli',
        'groundnut'
      ];
      extracted = crops.firstWhere(
        (c) => lower.contains(c),
        orElse: () => speechInput,
      );
      metadata = {
        'field': 'cropName',
        'confidence': 0.9,
        'originalInput': speechInput
      };
    } else if (field.toLowerCase().contains('date') ||
        field.toLowerCase().contains('day')) {
      extracted = _extractDate(lower) ?? '2026-08-26';
      metadata = {
        'field': 'date',
        'confidence': 0.8,
        'originalInput': speechInput
      };
    } else if (field.toLowerCase().contains('phone') ||
        field.toLowerCase().contains('mobile')) {
      extracted = RegExp(r'\d{10}').firstMatch(lower)?.group(0) ??
          speechInput.replaceAll(RegExp(r'[^0-9]'), '');
      metadata = {
        'field': 'phone',
        'confidence': 0.7,
        'originalInput': speechInput
      };
    } else {
      extracted = speechInput;
      metadata = {
        'field': field,
        'confidence': 0.6,
        'originalInput': speechInput,
        'note': 'Could not determine specific extraction pattern'
      };
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
    final match = RegExp(
            r'(\d{1,2})\s*(?:st|nd|rd|th)?\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*')
        .firstMatch(text);
    if (match != null) {
      final months = {
        'jan': '01',
        'feb': '02',
        'mar': '03',
        'apr': '04',
        'may': '05',
        'jun': '06',
        'jul': '07',
        'aug': '08',
        'sep': '09',
        'oct': '10',
        'nov': '11',
        'dec': '12',
      };
      final day = match.group(1)!.padLeft(2, '0');
      final month =
          months[match.group(2)!.toLowerCase().substring(0, 3)] ?? '01';
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
        'phosphorus': phValue >= 6.0
            ? 'Likely adequate'
            : 'May be locked — apply rock phosphate',
        'potassium': 'Test recommended for accurate assessment',
        'organicMatter': request.soilType.toLowerCase().contains('black')
            ? 'Typically good in black cotton soil'
            : 'Add FYM to improve',
      },
      'recommendations': [
        if (phValue < 6.0)
          'Apply agricultural lime at 2–4 tonnes/hectare to raise pH.',
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
            'description':
                'Walk through $farmName and check for any visible pest damage, wilting, or unusual growth patterns.',
            'category': 'inspection',
            'priority': 'high',
            'estimatedTime': '30 min',
            'timeWindow': '6:00 AM – 8:00 AM',
          },
          {
            'id': 't2_${farmName.hashCode}',
            'title': 'Irrigation check',
            'description':
                'Check soil moisture at 15 cm depth. Irrigate if soil is dry to touch. Ensure all drip/sprinkler systems are functioning.',
            'category': 'irrigation',
            'priority': crops.isNotEmpty ? 'high' : 'medium',
            'estimatedTime': '45 min',
            'timeWindow': '6:00 AM – 9:00 AM',
          },
          {
            'id': 't3_${farmName.hashCode}',
            'title': 'Weed management',
            'description':
                'Remove weeds from field borders and between crop rows. Prioritize areas near water channels.',
            'category': 'maintenance',
            'priority': 'medium',
            'estimatedTime': '1 hour',
            'timeWindow': '7:00 AM – 10:00 AM',
          },
          if (crops.isNotEmpty)
            {
              'id': 't4_${farmName.hashCode}',
              'title': 'Crop health monitoring — ${crops.join(", ")}',
              'description':
                  'Inspect ${crops.join(" and ")} for signs of pest infestation, nutrient deficiency, or disease. Take photos for AI analysis.',
              'category': 'monitoring',
              'priority': 'high',
              'estimatedTime': '30 min',
              'timeWindow': '7:00 AM – 9:00 AM',
            },
          {
            'id': 't5_${farmName.hashCode}',
            'title': 'Record keeping',
            'description':
                'Update farm diary: note any observations, input usage, and weather conditions for today.',
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
            'description':
                'Go to Farm Settings and add your farm details to receive AI-generated daily tasks.',
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
      'totalTasks': tasks.fold<int>(
          0, (sumTotal, farm) => sumTotal + ((farm['tasks'] as List).length)),
      'farmTasks': tasks,
      'source': 'VidhAI Mock Engine',
    });
    return AIResponse.ok(result, provider: 'mock');
  }

  AIResponse _mockCropRecommendation(RecommendationRequest request) {
    final farmProfile = request.farmProfile;
    final soilType =
        (farmProfile['soilType'] ?? 'alluvial').toString().toLowerCase();
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
          'reasoning':
              'Excellent match for $soilType soil during Kharif season. High market demand.',
          'riskLevel': 'Low',
          'marketPrice': '₹2,183/quintal (MSP)',
        },
        {
          'crop': 'Cotton (Kapas)',
          'suitabilityScore': 85,
          'expectedYield': '20–25 quintals/hectare',
          'waterRequirement': 'Medium (700–1300 mm)',
          'investmentLevel': 'High',
          'reasoning':
              'Good returns if Bt cotton variety is used. Requires careful pest management.',
          'riskLevel': 'Medium',
          'marketPrice': '₹6,620/quintal (MSP)',
        },
        {
          'crop': 'Soybean',
          'suitabilityScore': 80,
          'expectedYield': '1.2–1.5 tonnes/hectare',
          'waterRequirement': 'Medium (450–650 mm)',
          'investmentLevel': 'Low',
          'reasoning':
              'Low-cost crop with good nitrogen fixation. Good rotation crop.',
          'riskLevel': 'Medium',
          'marketPrice': '₹4,300/quintal (MSP)',
        },
        {
          'crop': 'Maize (Makka)',
          'suitabilityScore': 75,
          'expectedYield': '5–8 tonnes/hectare',
          'waterRequirement': 'Medium (500–800 mm)',
          'investmentLevel': 'Medium',
          'reasoning':
              'Versatile crop with multiple market options (food, feed, industrial).',
          'riskLevel': 'Low',
          'marketPrice': '₹1,870/quintal (MSP)',
        },
        {
          'crop': 'Groundnut (Moongphali)',
          'suitabilityScore': 70,
          'expectedYield': '1.5–2.5 tonnes/hectare',
          'waterRequirement': 'Low–Medium (400–600 mm)',
          'investmentLevel': 'Low',
          'reasoning':
              'Good oilseed option. Fixes nitrogen and improves soil health.',
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
          'reasoning':
              'Primary Rabi crop with assured MSP procurement. Excellent for $soilType soil.',
          'riskLevel': 'Low',
          'marketPrice': '₹2,275/quintal (MSP)',
        },
        {
          'crop': 'Mustard (Sarson)',
          'suitabilityScore': 82,
          'expectedYield': '1.2–1.8 tonnes/hectare',
          'waterRequirement': 'Low (350–500 mm)',
          'investmentLevel': 'Low',
          'reasoning':
              'Excellent oilseed for Rabi season. Low water requirement.',
          'riskLevel': 'Low',
          'marketPrice': '₹5,450/quintal (MSP)',
        },
        {
          'crop': 'Chickpea (Chana)',
          'suitabilityScore': 80,
          'expectedYield': '1.5–2.0 tonnes/hectare',
          'waterRequirement': 'Low (300–400 mm)',
          'investmentLevel': 'Low',
          'reasoning':
              'High-protein pulse. Fixes atmospheric nitrogen. Very low water needs.',
          'riskLevel': 'Low',
          'marketPrice': '₹5,230/quintal (MSP)',
        },
        {
          'crop': 'Potato (Aloo)',
          'suitabilityScore': 75,
          'expectedYield': '20–30 tonnes/hectare',
          'waterRequirement': 'Medium (500–700 mm)',
          'investmentLevel': 'Medium–High',
          'reasoning':
              'High-value crop with strong market demand. Requires good drainage.',
          'riskLevel': 'Medium',
          'marketPrice': 'Market-linked',
        },
        {
          'crop': 'Peas (Matar)',
          'suitabilityScore': 72,
          'expectedYield': '1.0–1.5 tonnes/hectare',
          'waterRequirement': 'Low (300–400 mm)',
          'investmentLevel': 'Low',
          'reasoning':
              'Good pulse crop. Improves soil fertility through nitrogen fixation.',
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
      'disclaimer':
          'These are general recommendations. Consult your local KVK for region-specific advice.',
      'source': 'VidhAI Mock Engine',
    });
    return AIResponse.ok(result, provider: 'mock');
  }
}
