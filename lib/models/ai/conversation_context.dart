import 'ai_message.dart';

/// Bounded conversation context for the active session.
/// Keeps the last [maxTurns] turns (a reasonable window) plus farmer context.
class ConversationContext {
  static const int maxTurns = 12;

  final List<AIMessage> _messages = [];
  Map<String, dynamic> userProfile;
  List<Map<String, dynamic>> farms;
  String language;

  ConversationContext({
    this.userProfile = const {},
    this.farms = const [],
    this.language = 'en',
  });

  List<AIMessage> get messages => List.unmodifiable(_messages);

  /// Adds a user/assistant pair; trims history beyond the window.
  void addExchange(AIMessage userMessage, AIMessage assistantMessage) {
    _messages.add(userMessage);
    if (assistantMessage.content.isNotEmpty) {
      _messages.add(assistantMessage);
    }
    _trim();
  }

  void addMessage(AIMessage message) {
    _messages.add(message);
    _trim();
  }

  /// Rebuilds the session from persisted history (user/assistant turns only).
  void restore(List<AIMessage> messages) {
    _messages.clear();
    for (final m in messages) {
      if (m.role == 'user' || m.role == 'assistant') _messages.add(m);
    }
    _trim();
  }

  /// Full message list sent to Groq (keeps tool calls/results aligned).
  List<AIMessage> historyWithToolResults() => _messages.toList();

  bool get hasHistory => _messages.isNotEmpty;

  void clear() => _messages.clear();

  /// JSON object forwarded to the backend for assembling farmer-aware prompts.
  Map<String, dynamic> toBackendContext([Map<String, dynamic>? extras]) {
    return {
      'userProfile': userProfile,
      'farms': farms,
      if (extras != null && extras.isNotEmpty) ...extras,
    };
  }

  void _trim() {
    if (_messages.length <= maxTurns) return;
    var excess = _messages.length - maxTurns;
    while (excess > 0 && _messages.isNotEmpty) {
      _messages.removeAt(0);
      excess--;
    }
  }
}
