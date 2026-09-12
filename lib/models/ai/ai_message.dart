import 'ai_tool_call.dart';

/// A single message in the AI conversation sent to the Groq brain.
class AIMessage {
  final String role; // 'system' | 'user' | 'assistant' | 'tool'
  final String content;
  final String? toolCallId;
  final List<AIToolCall>? toolCalls;

  const AIMessage({
    required this.role,
    this.content = '',
    this.toolCallId,
    this.toolCalls,
  });

  const AIMessage.user(String content) : this(role: 'user', content: content);
  const AIMessage.assistant(String content)
      : this(role: 'assistant', content: content);

  const AIMessage.fromToolResult(this.toolCallId, String result)
      : role = 'tool',
        content = result,
        toolCalls = null;

  /// Serializes to the Groq/OpenAI wire format.
  Map<String, dynamic> toWire() {
    final map = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (toolCallId != null) map['tool_call_id'] = toolCallId;
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      map['tool_calls'] = toolCalls!.map((t) => t.toWire()).toList();
    }
    return map;
  }

  @override
  String toString() =>
      'AIMessage($role: ${content.length > 60 ? '${content.substring(0, 60)}…' : content})';
}
