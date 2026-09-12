import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:vidhai/data/models/farm_records.dart';

class FarmRecordsService {
  static final FarmRecordsService _instance = FarmRecordsService._();
  factory FarmRecordsService() => _instance;
  FarmRecordsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  String _getUid() => FirebaseAuth.instance.currentUser?.uid ?? '';

  // --- Expenses ---
  Future<void> addExpense(ExpenseRecord record) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(record.id)
          .set(record.toMap());
    } catch (_) {}
    await _cacheExpensesLocally(record);
  }

  Future<void> updateExpense(ExpenseRecord record) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(record.id)
          .update(record.toMap());
    } catch (_) {}
  }

  Future<void> deleteExpense(String id) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .doc(id)
          .delete();
    } catch (_) {}
    await _removeCachedExpense(id);
  }

  Future<List<ExpenseRecord>> loadExpenses(String farmId) async {
    final uid = _getUid();
    if (uid.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .where('farmId', isEqualTo: farmId)
          .orderBy('date', descending: true)
          .get();
      final records =
          snap.docs.map((d) => ExpenseRecord.fromMap(d.data())).toList();
      return records;
    } catch (_) {
      return _loadCachedExpenses(farmId);
    }
  }

  Future<void> _cacheExpensesLocally(ExpenseRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'expenses_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != record.id)
        .toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<List<ExpenseRecord>> _loadCachedExpenses(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'expenses_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    return (json.decode(existing) as List)
        .map((m) => ExpenseRecord.fromMap(m))
        .toList();
  }

  Future<void> _removeCachedExpense(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('expenses_'));
    for (final key in keys) {
      final existing = prefs.getString(key) ?? '[]';
      final list =
          (json.decode(existing) as List).where((m) => m['id'] != id).toList();
      await prefs.setString(key, json.encode(list));
    }
  }

  // --- Pesticides ---
  Future<void> addPesticide(PesticideRecord record) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('pesticides')
          .doc(record.id)
          .set(record.toMap());
    } catch (_) {}
  }

  Future<List<PesticideRecord>> loadPesticides(String farmId) async {
    final uid = _getUid();
    if (uid.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('pesticides')
          .where('farmId', isEqualTo: farmId)
          .orderBy('date', descending: true)
          .get();
      return snap.docs.map((d) => PesticideRecord.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deletePesticide(String id) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('pesticides')
          .doc(id)
          .delete();
    } catch (_) {}
  }

  // --- Fertilizers ---
  Future<void> addFertilizer(FertilizerRecord record) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fertilizers')
          .doc(record.id)
          .set(record.toMap());
    } catch (_) {}
  }

  Future<List<FertilizerRecord>> loadFertilizers(String farmId) async {
    final uid = _getUid();
    if (uid.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('fertilizers')
          .where('farmId', isEqualTo: farmId)
          .orderBy('date', descending: true)
          .get();
      return snap.docs.map((d) => FertilizerRecord.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteFertilizer(String id) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fertilizers')
          .doc(id)
          .delete();
    } catch (_) {}
  }

  // --- Disease Records ---
  Future<void> addDisease(DiseaseRecord record) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diseases')
          .doc(record.id)
          .set(record.toMap());
    } catch (_) {}
  }

  Future<List<DiseaseRecord>> loadDiseases(String farmId) async {
    final uid = _getUid();
    if (uid.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('diseases')
          .where('farmId', isEqualTo: farmId)
          .orderBy('detectedDate', descending: true)
          .get();
      return snap.docs.map((d) => DiseaseRecord.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> updateDisease(DiseaseRecord record) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diseases')
          .doc(record.id)
          .update(record.toMap());
    } catch (_) {}
  }

  Future<void> deleteDisease(String id) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('diseases')
          .doc(id)
          .delete();
    } catch (_) {}
  }

  String generateId() => _uuid.v4();
}
