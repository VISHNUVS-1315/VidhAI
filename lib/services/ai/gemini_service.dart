import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../models/ai/ai_message.dart';
import 'groq_service.dart';
import 'secure_api_client.dart';

/// Gemini central brain (chat + secure tool calling).
///
/// When a real Gemini key is compiled in (`--dart-define=GEMINI_API_KEY=...`)
/// it calls the Gemini REST `generateContent` endpoint directly (test builds).
/// Otherwise it proxies through the secure backend `/ai/chat` with
/// `provider: 'gemini'`, keeping the key server-side.
///
/// It speaks the same [GroqChatResult] wire model as [GroqService], so the
/// assistant and orchestrator can swap brains without touching their logic.
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  final SecureApiClient _client = SecureApiClient.instance;

  static const String _geminiBase =
      'https://generativelanguage.googleapis.com/v1beta';
  static const Duration _timeout = Duration(seconds: 150);

  Future<GroqChatResult> chat({
    required List<AIMessage> messages,
    required String language,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? tools,
    void Function(String delta)? onDelta,
    Duration? timeout,
  }) async {
    if (AppConfig.hasConfiguredGeminiKey) {
      return _chatWithGeminiDirect(
        messages: messages,
        language: language,
        context: context,
        tools: tools,
        onDelta: onDelta,
        timeout: timeout,
      );
    }
    return _chatViaSecureBackend(
      messages: messages,
      language: language,
      context: context,
      tools: tools,
      onDelta: onDelta,
    );
  }

  Future<GroqChatResult> _chatViaSecureBackend({
    required List<AIMessage> messages,
    required String language,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? tools,
    void Function(String delta)? onDelta,
  }) async {
    final json = await _client.post('/ai/chat', {
      'messages': messages.map((m) => m.toWire()).toList(),
      'language': language,
      'provider': 'gemini',
      if (context != null && context.isNotEmpty) 'context': context,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
    });

    if (json['success'] != true) {
      return GroqChatResult(
        success: false,
        error: (json['error'] as String?) ?? 'AI service unavailable.',
      );
    }

    final toolCalls = <GroqToolCall>[];
    final raw = json['toolCalls'];
    if (raw is List) {
      for (final call in raw.whereType<Map>()) {
        toolCalls.add(GroqToolCall(
          id: (call['id'] ?? '').toString(),
          functionName: (call['function']?['name'] ?? '').toString(),
          arguments: _args(call['arguments']),
        ));
      }
    }

    final content = (json['content'] as String?) ?? '';
    if (onDelta != null && content.isNotEmpty) onDelta(content);

    return GroqChatResult(
      success: true,
      content: content,
      toolCalls: toolCalls,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Direct call to Gemini `generateContent`. The key is set at build time via
  /// --dart-define and is never stored or committed.
  Future<GroqChatResult> _chatWithGeminiDirect({
    required List<AIMessage> messages,
    required String language,
    required Map<String, dynamic>? context,
    required List<Map<String, dynamic>>? tools,
    required void Function(String delta)? onDelta,
    Duration? timeout,
  }) async {
    final apiKey = AppConfig.geminiApiKey;
    if (!AppConfig.hasConfiguredGeminiKey) {
      return GroqChatResult(
          success: false, error: 'Gemini API key is not configured.');
    }

    final uri = Uri.parse(
      '$_geminiBase/models/${AppConfig.geminiModel}:generateContent?key=$apiKey',
    );
    final body = <String, dynamic>{
      'contents': toGeminiContents(messages),
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt(language, context)},
        ],
      },
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': AppConfig.maxOutputTokens,
      },
      if (tools != null && tools.isNotEmpty)
        'tools': [
          {'functionDeclarations': toFunctionDeclarations(tools)},
        ],
    };

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout ?? _timeout);

    if (response.statusCode != 200) {
      return GroqChatResult(
        success: false,
        error: _describeGeminiError(
            response.statusCode, utf8.decode(response.bodyBytes)),
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      return const GroqChatResult(
          success: false, error: 'Gemini returned an invalid response.');
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final finish = decoded['promptFeedback'];
      if (finish is Map && (finish['blockReason'] as String?) != null) {
        return GroqChatResult(
          success: false,
          error:
              'Gemini blocked the request (${finish['blockReason']}). Please rephrase.',
        );
      }
      return const GroqChatResult(
          success: false, error: 'Gemini returned no response.');
    }

    return parseDirectResponse(decoded, onDelta: onDelta);
  }

  /// Pure parser for a Gemini `generateContent` response → our wire model.
  /// Exposed for unit tests.
  static GroqChatResult parseDirectResponse(
    Map<String, dynamic> decoded, {
    void Function(String delta)? onDelta,
  }) {
    final candidates = (decoded['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) {
      return const GroqChatResult(
          success: false, error: 'Gemini returned no response.');
    }
    final first = candidates.first;
    final content = first is Map ? (first['content'] as Map?) : null;
    final parts = (content?['parts'] as List?) ?? const [];

    final text = parts
        .whereType<Map>()
        .map((p) => p['text'])
        .whereType<String>()
        .join('\n')
        .trim();

    final toolCalls = <GroqToolCall>[];
    for (final part in parts.whereType<Map>()) {
      final fc = part['functionCall'];
      if (fc is Map) {
        final name = (fc['name'] ?? '').toString();
        toolCalls.add(GroqToolCall(
          id: name.isNotEmpty ? name : 'call',
          functionName: name,
          arguments: _args(fc['args']),
        ));
      }
    }

    if (onDelta != null && text.isNotEmpty) onDelta(text);
    return GroqChatResult(
      success: true,
      content: text,
      toolCalls: toolCalls,
      metadata: const {'provider': 'gemini', 'stream': false},
    );
  }

  /// Converts Groq/OpenAI-wire history into Gemini `contents` turns
  /// (user/model text + functionCall / functionResponse parts). Exposed so
  /// the tool-loop semantics can be unit-tested.
  static List<Map<String, dynamic>> toGeminiContents(List<AIMessage> messages) {
    final contents = <Map<String, dynamic>>[];
    final callIdToName = <String, String>{};

    for (final m in messages) {
      switch (m.role) {
        case 'user':
          if (m.content.trim().isEmpty) continue;
          contents.add({
            'role': 'user',
            'parts': [
              {'text': m.content},
            ],
          });
        case 'assistant':
          final hasToolCalls = m.toolCalls != null && m.toolCalls!.isNotEmpty;
          if (hasToolCalls) {
            final parts = <Map<String, dynamic>>[];
            if (m.content.trim().isNotEmpty) {
              parts.add({'text': m.content});
            }
            for (final c in m.toolCalls!) {
              callIdToName[c.id] = c.name;
              parts.add({
                'functionCall': {'name': c.name, 'args': c.arguments},
              });
            }
            contents.add({'role': 'model', 'parts': parts});
          } else if (m.content.trim().isNotEmpty) {
            contents.add({
              'role': 'model',
              'parts': [
                {'text': m.content},
              ],
            });
          }
        case 'tool':
          final id = m.toolCallId ?? '';
          final name = callIdToName[id] ?? id;
          contents.add({
            'role': 'function',
            'parts': [
              {
                'functionResponse': {
                  'name': name,
                  'response': _decodeResult(m.content),
                },
              },
            ],
          });
      }
    }
    return contents;
  }

  /// Converts Groq/OpenAI function-calling specs into Gemini
  /// `functionDeclarations`. Exposed for unit tests.
  static List<Map<String, dynamic>> toFunctionDeclarations(
    List<Map<String, dynamic>> tools,
  ) {
    final decls = <Map<String, dynamic>>[];
    for (final spec in tools.whereType<Map>()) {
      final fn = spec['function'];
      if (fn is! Map) continue;
      final name = (fn['name'] ?? '').toString();
      if (name.isEmpty) continue;
      final parameters = fn['parameters'];
      decls.add({
        'name': name,
        'description': (fn['description'] ?? '').toString(),
        if (parameters is Map) 'parameters': parameters,
      });
    }
    return decls;
  }

  static Object _decodeResult(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map || decoded is List) return decoded;
      return {'text': content};
    } catch (_) {
      return {'text': content};
    }
  }

  static Map<String, dynamic> _args(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const {};
  }

  String _systemPrompt(String language, Map<String, dynamic>? context) {
    final langName = switch (language) {
      'ta' => 'Tamil',
      'mr' => 'Marathi',
      'hi' => 'Hindi',
      'te' => 'Telugu',
      'kn' => 'Kannada',
      'ml' => 'Malayalam',
      _ => 'English',
    };
    final sb = StringBuffer()
      ..writeln(
          'You are VidhAI, the farmer assistant inside the VidhAI agricultural app (Maharashtra, India).')
      ..writeln(
          "Respond in $langName unless the farmer writes in another language.")
      ..writeln(
          'Be friendly, concise and practical. Use the farmer\'s name if known.')
      ..writeln(
          'Use the provided tools whenever the farmer asks about their own data (farms, weather, market prices, tasks, profile) or asks you to fill a form field or perform an action.')
      ..writeln(
          'Never invent data; rely on tool results. When a tool returns nothing, say so.');
    if (context != null && context.isNotEmpty) {
      sb.writeln();
      sb.writeln('Farmer context (JSON): ${jsonEncode(context)}');
    }
    return sb.toString();
  }

  String _describeGeminiError(int status, String body) {
    if (status == 401 || status == 403) {
      return 'Invalid or missing Gemini API key.';
    }
    if (status == 429) {
      return 'Gemini rate limit reached. Try again in a moment.';
    }
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
    } catch (_) {}
    return 'Gemini request failed (HTTP $status).';
  }
}
