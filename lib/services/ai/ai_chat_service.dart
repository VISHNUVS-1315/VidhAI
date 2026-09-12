import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'ai_service.dart';
import 'domain_services.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Chat Message Model
// ═══════════════════════════════════════════════════════════════════════════════

class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  factory ChatMessage.user(String content, {Map<String, dynamic>? metadata}) {
    return ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  factory ChatMessage.assistant(String content,
      {Map<String, dynamic>? metadata}) {
    return ChatMessage(
      id: const Uuid().v4(),
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? const Uuid().v4(),
      role: map['role'] ?? 'user',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  ChatMessage copyWith({
    String? content,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'ChatMessage($role: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
}

// ═══════════════════════════════════════════════════════════════════════════════
// Chat Session
// ═══════════════════════════════════════════════════════════════════════════════

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  })  : title = title ?? 'New Conversation',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  int get messageCount => messages.length;

  String get preview {
    if (messages.isEmpty) return '';
    final last = messages.last;
    return last.content.length > 80
        ? '${last.content.substring(0, 80)}...'
        : last.content;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
      };

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      messages: (map['messages'] as List?)
              ?.map((m) => ChatMessage.fromMap(m))
              .toList() ??
          [],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ChatHistoryService — Manages conversation history per session
// ═══════════════════════════════════════════════════════════════════════════════

class ChatHistoryService {
  ChatHistoryService._();
  static final ChatHistoryService _instance = ChatHistoryService._();
  static ChatHistoryService get instance => _instance;

  final VidhAIChatService _chatService = VidhAIChatService.instance;

  final Map<String, ChatSession> _sessions = {};
  String? _activeSessionId;

  // ── Session Management ───────────────────────────────────────────────────

  /// Creates a new chat session and sets it as active.
  ChatSession createSession({String? title}) {
    final session = ChatSession(
      id: const Uuid().v4(),
      title: title ?? 'New Conversation',
    );
    _sessions[session.id] = session;
    _activeSessionId = session.id;
    return session;
  }

  /// Sets the active session by ID.
  bool setActiveSession(String sessionId) {
    if (_sessions.containsKey(sessionId)) {
      _activeSessionId = sessionId;
      return true;
    }
    return false;
  }

  /// Gets the currently active session.
  ChatSession? get activeSession {
    if (_activeSessionId == null) return null;
    return _sessions[_activeSessionId];
  }

  /// Gets a session by ID.
  ChatSession? getSession(String sessionId) => _sessions[sessionId];

  /// Returns all sessions sorted by most recently updated first.
  List<ChatSession> get sessions {
    final list = _sessions.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Deletes a session. If it was active, clears the active session.
  void deleteSession(String sessionId) {
    _sessions.remove(sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = sessions.isNotEmpty ? sessions.first.id : null;
    }
  }

  // ── Message Management ───────────────────────────────────────────────────

  /// Sends a message in the active session and gets AI response.
  /// Creates a session if none is active.
  Future<ChatMessage> sendMessage(
    String content, {
    String language = 'en',
    Map<String, dynamic>? userProfile,
    List<Map<String, dynamic>>? farms,
  }) async {
    // Ensure we have an active session
    if (_activeSessionId == null || !_sessions.containsKey(_activeSessionId)) {
      createSession(title: _generateTitle(content));
    }

    final session = _sessions[_activeSessionId]!;

    // Add user message
    final userMessage = ChatMessage.user(content);
    session.messages.add(userMessage);

    // Update session title from first user message
    if (session.messages.where((m) => m.role == 'user').length == 1) {
      // Title is already set from createSession
    }

    // Get AI response
    final aiResponse = await _chatService.chat(
      content,
      language: language,
      userProfile: userProfile,
      farms: farms,
    );

    // Add assistant message
    final assistantMessage = ChatMessage.assistant(
      aiResponse,
      metadata: {'language': language},
    );
    session.messages.add(assistantMessage);
    session.updatedAt = DateTime.now();

    return assistantMessage;
  }

  /// Sends a message and returns the raw AI response object.
  Future<AIResponse> sendMessageRaw(
    String content, {
    String language = 'en',
    Map<String, dynamic>? userProfile,
    List<Map<String, dynamic>>? farms,
  }) async {
    if (_activeSessionId == null || !_sessions.containsKey(_activeSessionId)) {
      createSession(title: _generateTitle(content));
    }

    final session = _sessions[_activeSessionId]!;
    final userMessage = ChatMessage.user(content);
    session.messages.add(userMessage);

    final response = await _chatService.chatRaw(
      content,
      language: language,
      userProfile: userProfile,
      farms: farms,
    );

    final assistantMessage = ChatMessage.assistant(
      response.content,
      metadata: {
        'language': language,
        'provider': response.provider,
        'success': response.success,
      },
    );
    session.messages.add(assistantMessage);
    session.updatedAt = DateTime.now();

    return response;
  }

  /// Returns the message history for the active session.
  List<ChatMessage> getHistory() {
    return activeSession?.messages ?? [];
  }

  /// Returns the message history for a specific session.
  List<ChatMessage> getHistoryForSession(String sessionId) {
    return _sessions[sessionId]?.messages ?? [];
  }

  /// Clears the message history for the active session.
  void clearHistory() {
    if (_activeSessionId != null && _sessions.containsKey(_activeSessionId)) {
      _sessions[_activeSessionId]!.messages.clear();
      _sessions[_activeSessionId]!.updatedAt = DateTime.now();
    }
  }

  /// Clears the message history for a specific session.
  void clearHistoryForSession(String sessionId) {
    if (_sessions.containsKey(sessionId)) {
      _sessions[sessionId]!.messages.clear();
      _sessions[sessionId]!.updatedAt = DateTime.now();
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Exports the active session's history as a JSON string.
  String exportHistory() {
    final session = activeSession;
    if (session == null) return '{}';
    return jsonEncode(session.toMap());
  }

  /// Exports a specific session's history as a JSON string.
  String exportHistoryForSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return '{}';
    return jsonEncode(session.toMap());
  }

  /// Exports all sessions as a JSON string.
  String exportAllSessions() {
    final allSessions = sessions.map((s) => s.toMap()).toList();
    return jsonEncode({'sessions': allSessions});
  }

  /// Exports active session as a readable text format.
  String exportAsText() {
    final session = activeSession;
    if (session == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('VidhAI Chat Export');
    buffer.writeln('Session: ${session.title}');
    buffer.writeln('Date: ${session.createdAt.toLocal()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final msg in session.messages) {
      final role = msg.role == 'user' ? 'You' : 'VidhAI';
      final time = '${msg.timestamp.hour.toString().padLeft(2, '0')}:'
          '${msg.timestamp.minute.toString().padLeft(2, '0')}';
      buffer.writeln('[$time] $role:');
      buffer.writeln(msg.content);
      buffer.writeln();
    }

    return buffer.toString();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _generateTitle(String firstMessage) {
    if (firstMessage.length <= 40) return firstMessage;
    return '${firstMessage.substring(0, 37)}...';
  }

  /// Returns the total number of messages across all sessions.
  int get totalMessageCount {
    return sessions.fold<int>(0, (sum, s) => sum + s.messageCount);
  }

  /// Clears all sessions and resets state.
  void clearAll() {
    _sessions.clear();
    _activeSessionId = null;
  }
}
