import '../../core/config/app_config.dart';
import '../../models/ai/ai_message.dart';
import 'gemini_service.dart';
import 'groq_service.dart';

export 'groq_service.dart' show GroqChatResult, GroqToolCall;

/// The VidhAI central brain gateway.
///
/// Selects the orchestrator/assistant's AI brain:
///   * Gemini (central brain, spec): when AI_CHAT_PROVIDER=gemini is set at
///     build time or a real GEMINI_API_KEY was compiled in. Falls back to Groq
///     automatically whenever Gemini fails so the farmer always gets an answer.
///   * Groq (existing verified path): otherwise.
///
/// Both services speak the same [GroqChatResult] wire model, with tools in the
/// same Groq/OpenAI function-calling format.
class AiChatBrain {
  AiChatBrain._();

  /// Which provider the brain prefers for the current build.
  static String get activeProvider =>
      AppConfig.preferGeminiBrain ? 'gemini' : 'groq';

  static Future<GroqChatResult> chat({
    required List<AIMessage> messages,
    required String language,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? tools,
    void Function(String delta)? onDelta,
    Duration? timeout,
  }) async {
    if (AppConfig.preferGeminiBrain) {
      final gemini = await GeminiService.instance.chat(
        messages: messages,
        language: language,
        context: context,
        tools: tools,
        onDelta: onDelta,
        timeout: timeout,
      );
      if (gemini.success) return gemini;
    }
    return GroqService.instance.chat(
      messages: messages,
      language: language,
      context: context,
      tools: tools,
      onDelta: onDelta,
      timeout: timeout,
    );
  }
}
