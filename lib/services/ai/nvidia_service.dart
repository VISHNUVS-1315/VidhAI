import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/ai/ai_message.dart';
import 'secure_api_client.dart';

/// Tool/function request returned by the backend chat model.
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

/// Normalized backend chat response used by the app orchestrator.
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
/// authenticated VidhAI Render backend. App text chat is served by Groq.
class NvidiaService {
  NvidiaService._();
  static final NvidiaService instance = NvidiaService._();

  final SecureApiClient _client = SecureApiClient.instance;

  StreamSubscription<Map<String, dynamic>>? _streamSub;
  Completer<NvidiaChatResult>? _streamCompleter;
  String _streamBuffer = '';
  bool _streamCancelRequested = false;

  /// Aborts the in-flight streaming chat (user taps Stop). Any partial text
  /// already delivered is preserved so the UI can finalize it.
  void cancelCurrentStream() {
    _streamCancelRequested = true;
    final sub = _streamSub;
    _streamSub = null;
    sub?.cancel();
    final completer = _streamCompleter;
    _streamCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        NvidiaChatResult(
          success: true,
          content: _streamBuffer.trim(),
          toolCalls: const [],
          metadata: const {'cancelled': true, 'streamed': true},
        ),
      );
    }
    _streamBuffer = '';
  }

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
    final body = _requestBody(
      messages: messages,
      language: language,
      context: context,
      tools: tools,
      tier: tier,
      classify: classify,
      complexity: complexity,
      intent: intent,
    );
    if (onDelta != null) {
      return _chatStream(
        body: body,
        onDelta: onDelta,
        timeout: timeout,
      );
    }
    return _chatOnce(body, started: DateTime.now(), timeout: timeout);
  }

  Map<String, dynamic> _requestBody({
    required List<AIMessage> messages,
    required String language,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? tools,
    String? tier,
    bool classify = false,
    String? complexity,
    String? intent,
  }) {
    return {
      'messages': messages.map((m) => m.toWire()).toList(),
      'language': language,
      if (context != null && context.isNotEmpty) 'context': context,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (tier != null) 'tier': tier,
      if (classify) 'classify': true,
      if (complexity != null) 'complexity': complexity,
      if (intent != null) 'intent': intent,
    };
  }

  /// Non-streaming backend chat used by default and as the streaming fallback.
  Future<NvidiaChatResult> _chatOnce(
    Map<String, dynamic> body, {
    required DateTime started,
    Duration? timeout,
  }) async {
    try {
      final json = await _client
          .post('/ai/chat', body, debugTag: 'AiChat')
          .timeout(timeout ?? const Duration(seconds: 150));

      if (json['success'] != true) {
        return NvidiaChatResult(
          success: false,
          error: (json['error'] as String?) ?? 'AI service unavailable.',
        );
      }

      final toolCalls = <NvidiaToolCall>[];
      final raw = json['toolCalls'];
      if (raw is List) {
        toolCalls.addAll(_parseToolCalls(raw));
      }

      final content = (json['content'] as String?) ?? '';
      debugPrint(
        '[NvidiaService] chat legacy totalMs='
        '${DateTime.now().difference(started).inMilliseconds} '
        'content=${content.length} toolCalls=${toolCalls.length}',
      );
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
        error: 'AI request failed: ${e.runtimeType}',
      );
    }
  }

  /// Streaming variant: receives text deltas progressively via [onDelta].
  /// Uses the SSE backend `/ai/chat/stream`; the non-streaming path above
  /// remains the fallback for clients that cannot stream.
  Future<NvidiaChatResult> _chatStream({
    required Map<String, dynamic> body,
    required void Function(String delta) onDelta,
    Duration? timeout,
  }) async {
    final started = DateTime.now();
    final content = StringBuffer();
    final toolCalls = <NvidiaToolCall>[];
    var sawDelta = false;
    DateTime? firstDeltaAt;
    _streamBuffer = '';
    _streamCancelRequested = false;

    final completer = Completer<NvidiaChatResult>();
    _streamCompleter = completer;

    void finish(NvidiaChatResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    void handleEvent(Map<String, dynamic> event) {
      if (event.containsKey('delta')) {
        final delta = (event['delta'] as String?) ?? '';
        if (delta.isEmpty) return;
        if (!sawDelta) {
          sawDelta = true;
          firstDeltaAt = DateTime.now();
        }
        content.write(delta);
        _streamBuffer = content.toString();
        onDelta(delta);
        return;
      }
      if (event.containsKey('done')) {
        final finalContent = event['content'];
        if (content.isEmpty &&
            finalContent is String &&
            finalContent.isNotEmpty) {
          content.write(finalContent);
        }
        final raw = event['toolCalls'];
        if (raw is List) toolCalls.addAll(_parseToolCalls(raw));
        finish(_buildStreamedResult(
          content,
          toolCalls,
          started,
          sawDelta ? firstDeltaAt : null,
        ));
        return;
      }
      if (event.containsKey('error')) {
        finish(NvidiaChatResult(
          success: false,
          error: (event['error'] as String?) ?? 'AI service unavailable.',
        ));
      }
    }

    void handleError(Object error) {
      if (_streamCancelRequested) {
        finish(NvidiaChatResult(
          success: true,
          content: content.toString().trim(),
          toolCalls: toolCalls,
          metadata: const {'cancelled': true, 'streamed': true},
        ));
        return;
      }
      final partial = content.toString().trim();
      if (partial.isNotEmpty) {
        finish(NvidiaChatResult(
          success: true,
          content: partial,
          toolCalls: toolCalls,
          metadata: const {'partial': true, 'streamed': true},
        ));
        return;
      }
      // Stream failed before any token (e.g. the deployed backend does not
      // support /ai/chat/stream yet). Fall back to the non-streaming endpoint
      // once so chat still works; full-answer replacement is handled by the
      // controller via `assistantMsg == null` + empty `streamed`.
      unawaited(
        _chatOnce(body, started: started, timeout: timeout).then(
          finish,
          onError: (Object fallbackError) => finish(NvidiaChatResult(
            success: false,
            error: error is SecureApiException
                ? error.message
                : 'AI request failed: ${error.runtimeType}',
          )),
        ),
      );
    }

    final sub = _client
        .postStream(
          '/ai/chat/stream',
          body,
          debugTag: 'AiChatStream',
          timeout: timeout ?? const Duration(seconds: 150),
        )
        .listen(
          handleEvent,
          onError: handleError,
          onDone: () => finish(_buildStreamedResult(
            content,
            toolCalls,
            started,
            sawDelta ? firstDeltaAt : null,
          )),
          cancelOnError: true,
        );
    _streamSub = sub;

    final result = await completer.future;
    if (identical(_streamSub, sub)) _streamSub = null;
    _streamCompleter = null;
    return result;
  }

  NvidiaChatResult _buildStreamedResult(
    StringBuffer content,
    List<NvidiaToolCall> toolCalls,
    DateTime started,
    DateTime? firstDeltaAt,
  ) {
    final text = content.toString().trim();
    final totalMs = DateTime.now().difference(started).inMilliseconds;
    if (text.isEmpty && toolCalls.isEmpty) {
      return const NvidiaChatResult(
        success: false,
        error: 'The AI service returned an empty reply.',
      );
    }
    final ttfMs =
        firstDeltaAt?.difference(started).inMilliseconds;
    debugPrint(
      '[NvidiaService] stream ttfMs=${ttfMs ?? -1} '
      'totalMs=$totalMs content=${text.length} toolCalls=${toolCalls.length}',
    );
    return NvidiaChatResult(
      success: true,
      content: text,
      toolCalls: toolCalls,
      metadata: {
        'streamed': true,
        if (ttfMs != null) 'ttfMs': ttfMs,
        'totalMs': totalMs,
      },
    );
  }

  List<NvidiaToolCall> _parseToolCalls(List raw) {
    final out = <NvidiaToolCall>[];
    for (final call in raw.whereType<Map>()) {
      final fn = call['function'];
      final fnMap = fn is Map ? fn : const {};
      out.add(
        NvidiaToolCall(
          id: (call['id'] ?? '').toString(),
          functionName: (fnMap['name'] ?? '').toString(),
          arguments: _args(fnMap['arguments'] ?? call['arguments']),
        ),
      );
    }
    return out;
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
