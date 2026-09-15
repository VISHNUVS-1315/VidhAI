library;

import 'dart:convert';

/// Validates and repairs AI-provided structured outputs before the app uses
/// them. Kept pure and dependency-free so the same rules can protect the chat
/// brain, the vision/pest parser, and any future tool results.

class AiResponseValidator {
  AiResponseValidator._();

  /// Extracts the outermost JSON object from a model reply, tolerating markdown
  /// code fences and trailing commas. Returns null when no object can be found.
  static T? decodeJsonObject<T>(String? raw) {
    if (raw == null) return null;
    final body = extractJsonObject(raw);
    if (body == null) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is T) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Pulls the outermost `{...}` span out of free-form model text.
  ///
  /// Handles the common failure shapes: leading/following prose, markdown
  /// fences, stray braces inside thinking text, and trailing commas.
  static String? extractJsonObject(String raw) {
    var cleaned = raw.trim();
    cleaned = cleaned
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'```\s*$'), '')
        .trim();

    // Walk characters tracking the real nesting depth so that `{` / `}`
    // appearing inside string literals never confuse the search.
    var start = -1;
    var depth = 0;
    var inString = false;
    var escape = false;
    for (var i = 0; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (inString) {
        if (escape) {
          escape = false;
        } else if (ch == r'\') {
          escape = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        if (depth == 0) start = i;
        depth += 1;
      } else if (ch == '}') {
        depth -= 1;
        if (depth == 0 && start >= 0) {
          final candidate = cleaned.substring(start, i + 1);
          final parsed = _tryParseLenient(candidate);
          if (parsed != null) return parsed;
          // Invalid object (e.g. only a fragment with balanced braces):
          // keep scanning for a later, complete object.
          start = -1;
        }
      }
    }

    if (start >= 0) {
      final candidate = cleaned.substring(start);
      final parsed = _tryParseLenient(candidate);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? _tryParseLenient(String candidate) {
    final trimmed = candidate.trim();
    if (!trimmed.startsWith('{')) return null;
    final noTrailingCommas =
        trimmed.replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!);
    try {
      jsonDecode(noTrailingCommas);
      return noTrailingCommas;
    } catch (_) {
      return null;
    }
  }

  /// First non-empty string value from [keys] in [json] (e.g. 'text',
  /// 'content', 'description'). Used to normalise differing response shapes.
  static String firstText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is Map) {
        final nested = firstText(
          Map<String, dynamic>.from(value),
          keys,
        );
        if (nested.isNotEmpty) return nested;
      }
    }
    return '';
  }

  static bool hasNonEmptyText(Map<String, dynamic> json) =>
      firstText(json, const ['text', 'content', 'description']).isNotEmpty;

  /// Heuristic guard against empty or mid-generation truncations.
  static bool isPlausibleAiText(String content) {
    final trimmed = content.trim();
    return trimmed.isNotEmpty && !trimmed.endsWith('...') && trimmed.length > 1;
  }
}