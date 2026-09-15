import 'dart:async';
import 'dart:convert';

import '../../core/ai/ai_failure_handler.dart' as fail;
import '../../core/connectivity/connectivity_service.dart';
import '../../core/routing/app_navigator.dart';
import '../../models/ai/ai_message.dart';
import '../../models/ai/ai_tool_call.dart';
import '../../models/ai/conversation_context.dart';
import '../../tools/ai_tool.dart';
import 'ai_chat_brain.dart';
import 'secure_api_client.dart';

enum AiErrorKind { offline, auth, timeout, rateLimited, busy, generic }

class AiOrchestratorReply {
  final String text;
  final AiErrorKind? error;

  const AiOrchestratorReply.text(this.text) : error = null;
  const AiOrchestratorReply.error(AiErrorKind this.error) : text = '';

  bool get failed => error != null;
}

/// Raised internally after a retryable AI failure exhausts its allowed retries
/// (or the first non-retryable failure is hit), carrying the classified cause.
class _OrchestratorError implements Exception {
  final fail.AiFailure failure;
  _OrchestratorError(this.failure);
}

/// Drives the chat: builds a windowed conversation, calls the Groq brain,
/// executes any requested tools against the real app, and keeps looping up to
/// [maxToolRounds] until the assistant produces a final answer.
class AiOrchestrator {
  AiOrchestrator._();
  static final AiOrchestrator instance = AiOrchestrator._();

  static const int maxToolRounds = 4;

  final ConversationContext _context = ConversationContext();

  bool get hasHistory => _context.hasHistory;

  void reset() => _context.clear();

  /// Loads a persisted conversation back into the working context so the
  /// assistant can answer follow-ups coherently after a history open.
  void restoreFromHistory(List<AIMessage> messages) {
    final clean = <AIMessage>[
      for (final m in messages)
        if (m.content.trim().isNotEmpty) m,
    ];
    _context.restore(clean);
  }

  Future<AiOrchestratorReply> process({
    required String input,
    required String language,
    Map<String, dynamic>? userProfile,
    List<Map<String, dynamic>>? farms,
    Map<String, dynamic>? contextExtras,
    void Function(String delta)? onDelta,
  }) async {
    if (!await ConnectivityService.hasInternetConnection()) {
      return const AiOrchestratorReply.error(AiErrorKind.offline);
    }

    _context
      ..language = language
      ..userProfile = userProfile ?? const {}
      ..farms = (farms ?? const []).take(5).toList();

    final messages = <AIMessage>[
      ..._context.historyWithToolResults(),
      AIMessage.user(input.trim()),
    ];

    final contextJson = _context.toBackendContext(contextExtras);
    final toolSpecs = VidhAIToolRegistry.instance.groqSpecs();

    try {
      for (var round = 0; round < maxToolRounds; round++) {
        final result = await _chatWithRetries(
          messages: messages,
          language: language,
          context: contextJson,
          tools: toolSpecs,
          onDelta: onDelta,
        );

        if (!result.wantsToolCalls) {
          final content = result.content.trim();
          if (content.isNotEmpty) {
            _context.addExchange(
                AIMessage.user(input), AIMessage.assistant(content));
            return AiOrchestratorReply.text(content);
          }
          throw _OrchestratorError(
            fail.AiFailure(
              kind: fail.AiErrorKind.generic,
              message: 'The assistant returned an empty reply.',
            ),
          );
        }

        messages.add(AIMessage(
          role: 'assistant',
          content: '',
          toolCalls: result.toolCalls
              .map((t) => AIToolCall(
                  id: t.id, name: t.functionName, arguments: t.arguments))
              .toList(),
        ));

        for (final call in result.toolCalls) {
          final tool = VidhAIToolRegistry.instance.get(call.functionName);
          Object? output;
          if (tool == null) {
            output = {'error': 'Tool "${call.functionName}" is not available.'};
          } else {
            try {
              output = await tool.execute(call.arguments,
                  navigatorKey: AppNavigator.key);
            } catch (e) {
              output = {'error': 'Tool execution failed.'};
            }
          }
          messages.add(AIMessage.fromToolResult(call.id, jsonEncode(output)));
        }
      }
      throw _OrchestratorError(
        fail.AiFailure(
          kind: fail.AiErrorKind.generic,
          message: 'The assistant could not finish its reply.',
        ),
      );
    } on _OrchestratorError catch (e) {
      return _replyFromFailure(e.failure);
    } on SecureApiException catch (e) {
      return _replyFromFailure(fail.AiFailureHandler.fromStatus(e.statusCode, e.message));
    } catch (e) {
      return _replyFromFailure(fail.AiFailureHandler.fromError(e));
    }
  }

  /// Runs one chat attempt, retrying classified retryable failures (timeout,
  /// rate-limit, 5xx) with backoff. Returns a successful result or throws
  /// [_OrchestratorError] carrying the final classified failure.
  Future<GroqChatResult> _chatWithRetries({
    required List<AIMessage> messages,
    required String language,
    required Map<String, dynamic> context,
    required List<Map<String, dynamic>> tools,
    void Function(String delta)? onDelta,
  }) async {
    var retried = 0;
    while (true) {
      try {
        final result = await AiChatBrain.chat(
          messages: messages,
          language: language,
          context: context,
          tools: tools,
          onDelta: onDelta,
        );
        if (result.success) return result;
        final failure = fail.AiFailureHandler.fromError(result.error ?? '');
        if (fail.AiFailureHandler.shouldRetry(failure, retried)) {
          retried += 1;
          await Future<void>.delayed(
            fail.AiFailureHandler.backoffForAttempt(retried - 1),
          );
          continue;
        }
        throw _OrchestratorError(failure);
      } on SecureApiException catch (e) {
        final failure = e.statusCode == null
            ? fail.AiFailureHandler.fromError(e)
            : fail.AiFailureHandler.fromStatus(e.statusCode, e.message);
        if (fail.AiFailureHandler.shouldRetry(failure, retried)) {
          retried += 1;
          await Future<void>.delayed(
            fail.AiFailureHandler.backoffForAttempt(retried - 1),
          );
          continue;
        }
        throw _OrchestratorError(failure);
      }
    }
  }

  AiOrchestratorReply _replyFromFailure(fail.AiFailure failure) {
    final kind = switch (failure.kind) {
      fail.AiErrorKind.offline => AiErrorKind.offline,
      fail.AiErrorKind.auth => AiErrorKind.auth,
      fail.AiErrorKind.timeout => AiErrorKind.timeout,
      fail.AiErrorKind.rateLimited => AiErrorKind.rateLimited,
      fail.AiErrorKind.busy => AiErrorKind.busy,
      fail.AiErrorKind.generic => AiErrorKind.generic,
    };
    return AiOrchestratorReply.error(kind);
  }
}
