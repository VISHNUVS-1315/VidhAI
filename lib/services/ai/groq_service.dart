import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../models/ai/ai_message.dart';
import 'secure_api_client.dart';

/// A structured tool request returned by the AI brain (wire model).
class GroqToolCall {
  final String id;
  final String functionName;
  final Map<String, dynamic> arguments;

  const GroqToolCall({
    required this.id,
    required this.functionName,
    this.arguments = const {},
  });
}

class GroqChatResult {
  final bool success;
  final String content;
  final List<GroqToolCall> toolCalls;
  final String? error;
  final Map<String, dynamic>? metadata;

  const GroqChatResult({
    this.success = false,
    this.content = '',
    this.toolCalls = const [],
    this.error,
    this.metadata,
  });

  bool get wantsToolCalls => toolCalls.isNotEmpty;
}

/// Speaks to the Groq brain.
///
/// When a Groq API key is compiled in (`--dart-define=GROQ_API_KEY=...`) it
/// streams responses directly from Groq in real time. Otherwise it falls back
/// to the secure VidhAI backend proxy, which holds the keys server-side.
class GroqService {
  GroqService._();
  static final GroqService instance = GroqService._();

  final SecureApiClient _client = SecureApiClient.instance;

  static const _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const _timeout = Duration(seconds: 150);

  /// Sends a chat request. When [onDelta] is provided it fires with each
  /// incremental token of the final assistant reply as it arrives (streaming).
  Future<GroqChatResult> chat({
    required List<AIMessage> messages,
    required String language,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? tools,
    void Function(String delta)? onDelta,
    Duration? timeout,
  }) async {
    final apiKey = AppConfig.groqApiKey;
    if (apiKey.isNotEmpty) {
      return _chatWithGroqDirect(
        messages: messages,
        language: language,
        context: context,
        tools: tools,
        onDelta: onDelta,
        apiKey: apiKey,
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

  /// Direct, streaming call to the Groq Inference API. The API key is set at
  /// build time via --dart-define and is never stored or committed.
  Future<GroqChatResult> _chatWithGroqDirect({
    required List<AIMessage> messages,
    required String language,
    required Map<String, dynamic>? context,
    required List<Map<String, dynamic>>? tools,
    required void Function(String delta)? onDelta,
    required String apiKey,
    Duration? timeout,
  }) async {
    final wireMessages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': _systemPrompt(language, context),
      },
      ...messages.map((m) => m.toWire()),
    ];

    final request = http.Request('POST', Uri.parse(_groqEndpoint))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': AppConfig.groqModel,
        'messages': wireMessages,
        'stream': true,
        'temperature': 0.7,
        if (tools != null && tools.isNotEmpty) 'tools': tools,
      });

    final streamed =
        await http.Client().send(request).timeout(timeout ?? _timeout);
    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      final hint = _describeGroqError(streamed.statusCode, body);
      return GroqChatResult(success: false, error: hint);
    }

    var buffer = StringBuffer();
    var content = StringBuffer();
    var reasoning = StringBuffer();
    final toolAccumulator = <int, _GroqToolAccumulator>{};

    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      while (true) {
        final lineEnd = buffer.toString().indexOf('\n');
        if (lineEnd < 0) break;
        final line = buffer.toString().substring(0, lineEnd).trim();
        buffer = StringBuffer(buffer.toString().substring(lineEnd + 1));
        if (line.isEmpty) continue;

        final payload = _sseData(line);
        if (payload == null || payload == '[DONE]') continue;

        try {
          final decoded = jsonDecode(payload) as Map<String, dynamic>;
          final choices = (decoded['choices'] as List?) ?? const [];
          if (choices.isEmpty) continue;
          final delta = ((choices.first as Map)['delta'] as Map?) ?? const {};

          final token = delta['content'];
          if (token is String && token.isNotEmpty) {
            content.write(token);
            if (onDelta != null) onDelta(token);
          }

          final thought = delta['reasoning'];
          if (thought is String && thought.isNotEmpty) {
            reasoning.write(thought);
          }

          final rawCalls = delta['tool_calls'];
          if (rawCalls is List) {
            for (final raw in rawCalls.whereType<Map>()) {
              final index = (raw['index'] as num?)?.toInt() ?? 0;
              final acc = toolAccumulator.putIfAbsent(
                index,
                () => _GroqToolAccumulator(),
              );
              final id = raw['id'];
              if (id is String && id.isNotEmpty) acc.id = id;
              final fn = raw['function'];
              if (fn is Map) {
                final name = fn['name'];
                if (name is String && name.isNotEmpty) acc.name += name;
                final args = fn['arguments'];
                if (args is String && args.isNotEmpty) acc.arguments += args;
              }
            }
          }
        } catch (_) {
          // Skip malformed SSE frames (e.g. keep-alive comments).
        }
      }
    }

    final toolCalls = toolAccumulator.values
        .map((a) => GroqToolCall(
              id: a.id,
              functionName: a.name,
              arguments: _args(a.arguments),
            ))
        .toList();

    // Reasoning-capable models (e.g. GPT-OSS) can stream only "reasoning"
    // when the reply budget runs out. Fall back to it so the farmer never sees
    // an empty "something went wrong" for a model that actually answered.
    var text = content.toString();
    if (text.trim().isEmpty && toolCalls.isEmpty) {
      text = reasoning.toString().trim();
    }

    return GroqChatResult(
      success: true,
      content: text,
      toolCalls: toolCalls,
      metadata: const {'stream': true},
    );
  }

  String _systemPrompt(String language, Map<String, dynamic>? context) {
    final langName = _languageName(language);
    final sb = StringBuffer()
      ..writeln(
          'You are VidhAI, the farmer assistant inside the VidhAI agricultural app (Maharashtra, India).')
      ..writeln(
          "Respond in $langName unless the farmer writes in another language.")
      ..writeln(
          "Be friendly, concise and practical. Use the farmer's name if known.")
      ..writeln(
          'Use the provided tools whenever the farmer asks about their own data (farms, weather, market prices, tasks, profile).')
      ..writeln(
          'Never invent data; rely on tool results. When a tool returns nothing, say so.');

    if (context != null && context.isNotEmpty) {
      sb.writeln();
      sb.writeln('Farmer context (JSON): ${jsonEncode(context)}');
    }
    return sb.toString();
  }

  String _languageName(String language) => language == 'ta'
      ? 'Tamil'
      : language == 'mr'
          ? 'Marathi'
          : language == 'hi'
              ? 'Hindi'
              : 'English';

  /// Extracts the payload of an SSE `data:` line, or null if it isn't one.
  String? _sseData(String line) {
    if (line.startsWith('data:')) {
      return line.substring(5).trim();
    }
    return null;
  }

  String _describeGroqError(int status, String body) {
    if (status == 401 || status == 403) {
      return 'Invalid or missing Groq API key.';
    }
    if (status == 429) {
      return 'Groq rate limit reached. Try again in a moment.';
    }
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
    } catch (_) {}
    return 'Groq request failed (HTTP $status).';
  }

  Map<String, dynamic> _args(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return const {};
  }
}

/// Accumulates a streaming tool-call fragment (id/name/arguments arrive in
/// multiple chunks across SSE deltas).
class _GroqToolAccumulator {
  String id = '';
  String name = '';
  String arguments = '';
}
