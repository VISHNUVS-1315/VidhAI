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

/// Drives app chat through the backend Groq brain, executes real app tools,
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

    // Do not attach every app tool schema to every ordinary farming question.
    // Tool definitions add prompt tokens and can materially increase NVIDIA
    // time-to-first-token. AI Chat already carries profile/farm context, so
    // only advertise tools that the current request can actually need.
    final toolSpecs = _toolSpecsForInput(input);

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

  List<Map<String, dynamic>> _toolSpecsForInput(String input) {
    final text = input.toLowerCase().trim();
    final wanted = <String>{};

    bool hasAny(Iterable<String> terms) =>
        terms.any((term) => text.contains(term));

    if (hasAny(const [
      'weather',
      'rain',
      'temperature',
      'forecast',
      'climate',
      'வானிலை',
      'மழை',
      'வெப்ப',
      'mazhai',
    ])) {
      wanted.add('GET_WEATHER');
    }

    if (hasAny(const [
      'price',
      'market',
      'mandi',
      'rate',
      'விலை',
      'சந்தை',
      'vilai',
    ])) {
      wanted.add('GET_MANDI_PRICES');
    }

    if (hasAny(const [
      'task',
      'to-do',
      'todo',
      'schedule',
      'reminder',
      'பணி',
      'வேலை',
    ])) {
      wanted.add('FARM_TASKS');
    }

    if (hasAny(const [
      'my farm',
      'farm details',
      'current crop',
      'my crop',
      'என் பண்ணை',
      'பண்ணை விவரம்',
    ])) {
      wanted.add('GET_FARM_DETAILS');
    }

    if (hasAny(const [
      'my profile',
      'my name',
      'account details',
      'என் பெயர்',
      'சுயவிவரம்',
    ])) {
      wanted.add('GET_PROFILE');
    }

    if (hasAny(const [
      'open ',
      'go to ',
      'navigate',
      'take me to',
      'show screen',
      'திற',
      'பக்கம்',
    ])) {
      wanted.add('OPEN_SCREEN');
    }

    // "What should I do now?" is a real-time farm-action question: the
    // assistant may need today's tasks and current weather, while farm context
    // itself is already supplied in the request context.
    if (hasAny(const [
      'what should i do',
      'what do i do now',
      'what to do now',
      'இப்ப என்ன செய்ய',
      'இப்போது என்ன செய்ய',
    ])) {
      wanted
        ..add('FARM_TASKS')
        ..add('GET_WEATHER');
    }

    if (wanted.isEmpty) return const [];

    return VidhAIToolRegistry.instance.aiSpecs().where((spec) {
      final function = spec['function'];
      if (function is! Map) return false;
      return wanted.contains((function['name'] ?? '').toString());
    }).toList();
  }

  /// Runs one chat attempt, retrying classified retryable failures (timeout,
  /// rate-limit, 5xx) with backoff. Returns a successful result or throws
  /// [_OrchestratorError] carrying the final classified failure.
  Future<NvidiaChatResult> _chatWithRetries({
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
