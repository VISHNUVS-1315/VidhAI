import 'dart:convert';

/// A structured, validated tool request returned by the AI brain.
class AIToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AIToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
  });

  /// Converts from the Groq/OpenAI function-call wire format.
  factory AIToolCall.fromWire(Map<String, dynamic> wire) {
    final rawArgs = wire['arguments'];
    Map<String, dynamic> parsedArgs = const {};
    if (rawArgs is Map) {
      parsedArgs = Map<String, dynamic>.from(rawArgs);
    } else if (rawArgs is String && rawArgs.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawArgs);
        if (decoded is Map<String, dynamic>) parsedArgs = decoded;
      } catch (_) {}
    }
    return AIToolCall(
      id: (wire['id'] ?? '').toString(),
      name: (wire['function']?['name'] ?? '').toString(),
      arguments: parsedArgs,
    );
  }

  Map<String, dynamic> toWire() {
    return {
      'id': id,
      'type': 'function',
      'function': {
        'name': name,
        'arguments': jsonEncode(arguments),
      },
    };
  }

  @override
  String toString() =>
      'AIToolCall($id: $name ${arguments.isEmpty ? '' : arguments})';
}
