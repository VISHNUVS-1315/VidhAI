import 'dart:convert';

import '../../models/ai/ai_message.dart';
import 'secure_api_client.dart';

/// Tool/function request returned by the NVIDIA model router.
class NvidiaToolCall {
  final String id;
  final String functionName;
  final Map<String, dynamic> arguments;

  const NvidiaToolCall({
    required this.id,
    required this.functionName,
    this.arguments = const {},
  });
}

/// Normalized NVIDIA chat response used by the app orchestrator.
class NvidiaChatResult {
  final bool success;
  final String content;
  final List<NvidiaToolCall> toolCalls;
  final String? error;
  final Map<String, dynamic>? metadata;

  const NvidiaChatResult({
    this.success = false,
    this.content = '',
    this.toolCalls = const [],
    this.error,
    this.metadata,
  });

  bool get wantsToolCalls => toolCalls.isNotEmpty;
}

/// Single production AI client.
///
/// The Flutter app never stores an AI key. Every request goes through the
/// authenticated VidhAI Render backend, which routes only to NVIDIA models.
class NvidiaService {
  NvidiaService._();
  static final NvidiaService instance = NvidiaService._();

  final SecureApiClient _client = SecureApiClient.instance;

  Future<NvidiaChatResult> chat({
    required List<AIMessage> messages,
    required String language,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? tools,
    void Function(String delta)? onDelta,
    Duration? timeout,
    String? tier,
    bool classify = false,
    String? complexity,
    String? intent,
  }) async {
    try {
      final json = await _client
          .post('/ai/chat', {
            'messages': messages.map((m) => m.toWire()).toList(),
            'language': language,
            if (context != null && context.isNotEmpty) 'context': context,
            if (tools != null && tools.isNotEmpty) 'tools': tools,
            if (tier != null) 'tier': tier,
            if (classify) 'classify': true,
            if (complexity != null) 'complexity': complexity,
            if (intent != null) 'intent': intent,
          }, debugTag: 'AiChat')
          .timeout(timeout ?? const Duration(seconds: 150));

      if (json['success'] != true) {
        return NvidiaChatResult(
          success: false,
          error: (json['error'] as String?) ?? 'NVIDIA AI service unavailable.',
        );
      }

      final toolCalls = <NvidiaToolCall>[];
      final raw = json['toolCalls'];
      if (raw is List) {
        for (final call in raw.whereType<Map>()) {
          final fn = call['function'];
          final fnMap = fn is Map ? fn : const {};
          toolCalls.add(
            NvidiaToolCall(
              id: (call['id'] ?? '').toString(),
              functionName: (fnMap['name'] ?? '').toString(),
              arguments: _args(fnMap['arguments'] ?? call['arguments']),
            ),
          );
        }
      }

      final content = (json['content'] as String?) ?? '';
      if (onDelta != null && content.isNotEmpty) onDelta(content);

      return NvidiaChatResult(
        success: true,
        content: content,
        toolCalls: toolCalls,
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );
    } on SecureApiException catch (e) {
      return NvidiaChatResult(success: false, error: e.message);
    } catch (e) {
      return NvidiaChatResult(
        success: false,
        error: 'NVIDIA AI request failed: ${e.runtimeType}',
      );
    }
  }

  Map<String, dynamic> _args(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }
}
