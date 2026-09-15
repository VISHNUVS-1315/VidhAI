import '../../models/ai/ai_message.dart';
import 'nvidia_service.dart';

export 'nvidia_service.dart' show NvidiaChatResult, NvidiaToolCall;

/// Single VidhAI AI brain.
///
/// All production chat requests go through the secure Render backend and are
/// served only by NVIDIA models. No provider switching or client-side AI keys.
class AiChatBrain {
  AiChatBrain._();

  static String get activeProvider => 'nvidia';

  static Future<NvidiaChatResult> chat({
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
  }) {
    return NvidiaService.instance.chat(
      messages: messages,
      language: language,
      context: context,
      tools: tools,
      onDelta: onDelta,
      timeout: timeout,
      tier: tier,
      classify: classify,
      complexity: complexity,
      intent: intent,
    );
  }
}
