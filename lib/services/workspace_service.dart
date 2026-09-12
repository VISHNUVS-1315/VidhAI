import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/models/workspace_note.dart';

/// Persistent storage for the farmer's Workspace notepad.
///
/// Local-first: every write lands in `SharedPreferences` (offline safe), then
/// mirrors to Firestore as a best-effort backup under
/// `users/{uid}/workspace_notes/{id}`.
class WorkspaceService {
  WorkspaceService._();

  static final WorkspaceService instance = WorkspaceService._();

  static const String _localKey = 'workspace_notes';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String _getUid() {
    try {
      return _auth.currentUser?.uid ?? '';
    } catch (_) {
      // Not authenticated / Firebase not initialised - local-only mode.
      return '';
    }
  }

  /// Saves (insert or replace by [WorkspaceNote.id]) a single note.
  Future<void> save(WorkspaceNote note) async {
    await _cacheUpsert(note);
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('workspace_notes')
            .doc(note.id)
            .set(note.toMap());
      } catch (_) {
        // Offline - local cache above still records it.
      }
    }
  }

  /// Deletes a note by id.
  Future<void> delete(String id) async {
    await _cacheRemove(id);
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('workspace_notes')
            .doc(id)
            .delete();
      } catch (_) {}
    }
  }

  /// Loads all notes, newest first. Firestore first, local cache fallback.
  Future<List<WorkspaceNote>> loadAll() async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('workspace_notes')
            .orderBy('createdAt', descending: true)
            .get();
        final notes =
            snap.docs.map((d) => WorkspaceNote.fromMap(d.data())).toList();
        if (notes.isNotEmpty) await _cacheReplaceAll(notes);
        return notes;
      } catch (_) {
        // Fall through to local cache.
      }
    }
    return _loadCached();
  }

  Future<List<WorkspaceNote>> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (json.decode(raw) as List)
          .map(
              (m) => WorkspaceNote.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheUpsert(WorkspaceNote note) async {
    final prefs = await SharedPreferences.getInstance();
    final list = <Map<String, dynamic>>[];
    final raw = prefs.getString(_localKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        list.addAll((json.decode(raw) as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .where((m) => m['id'] != note.id));
      } catch (_) {}
    }
    list.insert(0, note.toMap());
    await prefs.setString(_localKey, json.encode(list));
  }

  Future<void> _cacheRemove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (json.decode(raw) as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where((m) => m['id'] != id)
          .toList();
      await prefs.setString(_localKey, json.encode(list));
    } catch (_) {}
  }

  Future<void> _cacheReplaceAll(List<WorkspaceNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _localKey, json.encode(notes.map((n) => n.toMap()).toList()));
  }
}
