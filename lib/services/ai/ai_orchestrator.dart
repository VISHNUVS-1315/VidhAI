import 'dart:convert';

import '../../core/connectivity/connectivity_service.dart';
import '../../core/routing/app_navigator.dart';
import '../../models/ai/ai_message.dart';
import '../../models/ai/ai_tool_call.dart';
import '../../models/ai/conversation_context.dart';
import '../../tools/ai_tool.dart';
import 'ai_chat_brain.dart';
import 'secure_api_client.dart';

enum AiErrorKind { offline, auth, generic }

class AiOrchestratorReply {
  final String text;
  final AiErrorKind? error;

  const AiOrchestratorReply.text(this.text) : error = null;
  const AiOrchestratorReply.error(AiErrorKind this.error) : text = '';

  bool get failed => error != null;
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
        final result = await AiChatBrain.chat(
          messages: messages,
          language: language,
          context: contextJson,
          tools: toolSpecs,
          onDelta: onDelta,
        );

        if (!result.success) {
          return const AiOrchestratorReply.error(AiErrorKind.generic);
        }

        if (!result.wantsToolCalls) {
          final content = result.content.trim();
          if (content.isNotEmpty) {
            _context.addExchange(
                AIMessage.user(input), AIMessage.assistant(content));
            return AiOrchestratorReply.text(content);
          }
          return const AiOrchestratorReply.error(AiErrorKind.generic);
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
      return const AiOrchestratorReply.error(AiErrorKind.generic);
    } on SecureApiException catch (e) {
      if (e.statusCode == 401 || e.message.contains('Not signed in')) {
        return const AiOrchestratorReply.error(AiErrorKind.auth);
      }
      return const AiOrchestratorReply.error(AiErrorKind.generic);
    } catch (_) {
      return const AiOrchestratorReply.error(AiErrorKind.generic);
    }
  }
}
