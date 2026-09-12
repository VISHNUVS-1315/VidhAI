import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiConversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<Map<String, dynamic>> messages;

  AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  /// Last message preview for history list.
  String get lastPreview {
    for (var i = messages.length - 1; i >= 0; i--) {
      final content = messages[i]['content'];
      if (content is String && content.trim().isNotEmpty) return content;
    }
    return '';
  }
}

/// Persists AI conversations under `users/{uid}/ai_conversations/{id}`.
/// Keeps a lightweight offline cache (titles/metadata) in SharedPreferences so
/// history stays visible without internet and without a second database.
class AiConversationService {
  AiConversationService._();
  static final AiConversationService instance = AiConversationService._();

  static const String _cacheKey = 'ai_conversations_cache_v1';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('ai_conversations');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Persistence (Firestore) ────────────────────────────────────────────────

  Future<AiConversation?> loadConversation(String conversationId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _collection(uid).doc(conversationId).get();
      if (!doc.exists) return null;
      return _fromDoc(doc.id, doc.data() ?? {});
    } catch (_) {
      return null;
    }
  }

  Future<List<AiConversation>> listConversations() async {
    final uid = _uid;
    if (uid == null) return const [];
    try {
      final snap = await _collection(uid)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();
      final list = snap.docs
          .map((d) => _fromDoc(d.id, d.data()))
          .where((c) => c.messages.isNotEmpty)
          .toList();
      await _writeCache(list);
      return list;
    } catch (_) {
      return _readCache();
    }
  }

  Future<String> createConversation({String? title}) async {
    final uid = _uid;
    final id = _db.collection('_ids').doc().id;
    if (uid != null) {
      final now = Timestamp.now();
      try {
        await _collection(uid).doc(id).set({
          'title':
              (title?.trim().isNotEmpty ?? false) ? title!.trim() : 'New Chat',
          'createdAt': now,
          'updatedAt': now,
          'messages': [],
        });
      } catch (_) {
        // Offline: conversation will be attached on first append.
      }
    }
    final cacheTitle =
        (title == null || title.trim().isEmpty) ? 'New Chat' : title.trim();
    await _writeCacheEntry(id, cacheTitle);
    return id;
  }

  Future<void> appendMessage(
    String conversationId, {
    required String role,
    required String content,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final message = <String, dynamic>{
      'role': role,
      'content': content,
      'createdAt': Timestamp.now(),
      if (attachments != null && attachments.isNotEmpty)
        'attachments': attachments,
    };
    try {
      await _collection(uid).doc(conversationId).set({
        'updatedAt': Timestamp.now(),
        'messages': FieldValue.arrayUnion([message]),
      }, SetOptions(merge: true));
    } catch (_) {
      // Firestore offline queue handles the write when connectivity returns.
    }
    await _touchCacheEntry(conversationId, content);
  }

  Future<void> setTitle(String conversationId, String title) async {
    final uid = _uid;
    if (uid == null) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    try {
      await _collection(uid).doc(conversationId).set({
        'title': trimmed,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {}
    await _writeCacheEntry(conversationId, trimmed);
  }

  Future<void> deleteConversation(String conversationId) async {
    final uid = _uid;
    if (uid != null) {
      try {
        await _collection(uid).doc(conversationId).delete();
      } catch (_) {}
    }
    await _removeCacheEntry(conversationId);
  }

  // ── Mapping ────────────────────────────────────────────────────────────────

  AiConversation _fromDoc(String id, Map<String, dynamic> data) {
    final rawMessages = data['messages'];
    final messages = <Map<String, dynamic>>[];
    if (rawMessages is List) {
      for (final m in rawMessages) {
        if (m is Map) {
          messages.add(Map<String, dynamic>.from(m));
        }
      }
    }
    return AiConversation(
      id: id,
      title: (data['title'] as String?) ?? 'New Chat',
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      messages: messages,
    );
  }

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // ── Offline cache (SharedPreferences) ──────────────────────────────────────

  static String _previewOf(String content) {
    final lines = content.split('\n');
    return lines.first.trim().length > 60
        ? '${lines.first.trim().substring(0, 57)}…'
        : lines.first.trim();
  }

  Future<void> _writeCache(List<AiConversation> list) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = list
        .map((c) => {
              'id': c.id,
              'title': c.title,
              'updatedAt': c.updatedAt.toIso8601String(),
              'preview': _previewOf(c.lastPreview),
            })
        .toList();
    await prefs.setString(_cacheKey, jsonEncode(entries));
  }

  Future<void> _writeCacheEntry(String id, String title) async {
    final list = await _readCache();
    final existing = list.indexWhere((c) => c.id == id);
    if (existing >= 0) {
      list.removeAt(existing);
    }
    list.insert(
      0,
      AiConversation(
        id: id,
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      ),
    );
    await _writeCache(list);
  }

  Future<void> _touchCacheEntry(String id, String content) async {
    final list = await _readCache();
    final existing = list.indexWhere((c) => c.id == id);
    if (existing >= 0) {
      final c = list.removeAt(existing);
      list.insert(
        0,
        AiConversation(
            id: c.id,
            title: c.title,
            createdAt: c.createdAt,
            updatedAt: DateTime.now(),
            messages: []),
      );
    }
    await _writeCache(list);
  }

  Future<void> _removeCacheEntry(String id) async {
    final list = await _readCache();
    list.removeWhere((c) => c.id == id);
    await _writeCache(list);
  }

  Future<List<AiConversation>> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where((m) => m['id'] is String)
          .map((m) => AiConversation(
                id: m['id'] as String,
                title: (m['title'] as String?) ?? 'New Chat',
                createdAt: DateTime.now(),
                updatedAt:
                    DateTime.tryParse((m['updatedAt'] as String?) ?? '') ??
                        DateTime.now(),
                messages: [
                  if ((m['preview'] as String?)?.isNotEmpty == true)
                    {'role': 'assistant', 'content': m['preview']},
                ],
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
