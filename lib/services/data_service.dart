import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/crop_plan_models.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/data/models/notification_model.dart';

class DataService {
  static DataService? _instance;
  factory DataService() => _instance ??= DataService._();
  DataService._();

  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  String _getUid() => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ==================== USER PROFILE ====================

  Future<UserProfile?> loadProfile() async {
    final uid = _getUid();
    debugPrint(
        '[DataService] loadProfile AUTH UID=${uid.isEmpty ? "NONE" : uid}');
    if (uid.isNotEmpty) {
      debugPrint('[DataService] loadProfile DOC PATH=users/$uid');
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        final exists = doc.exists && doc.data() != null;
        debugPrint('[DataService] loadProfile DOC EXISTS=$exists');
        if (exists) {
          final data = doc.data()!;
          final profile = UserProfile(
            uid: uid,
            email: data['email'] ?? '',
            displayName: data['displayName'] ?? '',
            gender: data['gender'] ?? '',
            dateOfBirth: data['dateOfBirth'] != null
                ? DateTime.tryParse(data['dateOfBirth'])
                : null,
            age: data['age'] ?? 0,
            address: data['address'] != null
                ? AddressData.fromMap(
                    Map<String, dynamic>.from(data['address']))
                : null,
            avatarUrl: data['avatarUrl'] ?? '',
            role: data['role'] ?? 'farmer',
            isEmailVerified: data['isEmailVerified'] ?? false,
          );
          await _cacheProfile(profile);
          debugPrint('[DataService] loadProfile FETCH RESULT=SUCCESS (cached)');
          return profile;
        }
      } catch (e) {
        debugPrint('[DataService] loadProfile ERROR CODE=${_safeErrorCode(e)}');
      }
    }
    debugPrint('[DataService] loadProfile FETCH RESULT=FALLBACK to cache');
    return loadCachedProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _cacheProfile(profile);
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .set(profile.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> _cacheProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_profile', json.encode(profile.toMap()));
  }

  Future<UserProfile?> loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cached_profile');
    if (data != null) {
      try {
        return UserProfile.fromMap(json.decode(data));
      } catch (_) {}
    }
    // Fallback: build from individual SP keys (written at sign-in / onboarding).
    try {
      final name = prefs.getString('user_display_name') ?? '';
      final email = prefs.getString('user_email') ?? '';
      if (name.isEmpty && email.isEmpty) return null;
      return UserProfile(
        uid: prefs.getString('user_uid') ?? '',
        email: email,
        displayName: name,
        role: prefs.getString('selected_domain') ?? 'farmer',
        isEmailVerified: prefs.getBool('user_is_email_verified') ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  // ==================== FARMS ====================

  Future<List<FarmProfile>> loadFarms() async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('farms')
            .orderBy('index')
            .get();
        final farms =
            snap.docs.map((d) => FarmProfile.fromMap(d.data())).toList();
        if (farms.isNotEmpty) {
          await _cacheFarms(farms);
          return farms;
        }
      } catch (_) {}
    }
    return _loadCachedFarms();
  }

  Future<void> saveFarms(List<FarmProfile> farms) async {
    debugPrint('[DataService] saveFarms: ${farms.length} farms');
    await _cacheFarms(farms);
    debugPrint('[DataService] _cacheFarms completed');
    final uid = _getUid();
    debugPrint(
        '[DataService] uid: ${uid.isEmpty ? "EMPTY" : uid.substring(0, uid.length > 8 ? 8 : uid.length)}');
    if (uid.isNotEmpty) {
      try {
        final farmCol =
            _firestore.collection('users').doc(uid).collection('farms');
        debugPrint('[DataService] Firestore: fetching existing farms...');
        final existing = await farmCol.get();
        debugPrint(
            '[DataService] Firestore: ${existing.docs.length} existing docs');
        final batch = _firestore.batch();
        for (final doc in existing.docs) {
          batch.delete(doc.reference);
        }
        for (final farm in farms) {
          batch.set(farmCol.doc(farm.farmId), farm.toMap());
        }
        debugPrint('[DataService] Firestore: committing batch...');
        await batch.commit();
        debugPrint('[DataService] Firestore: batch committed OK');
      } catch (e) {
        debugPrint('[DataService] Firestore error (non-fatal): $e');
      }
    }
    debugPrint('[DataService] saveFarms DONE');
  }

  Future<void> addFarm(FarmProfile farm) async {
    final farms = await loadFarms();
    farms.add(farm);
    await saveFarms(farms);
  }

  Future<void> updateFarm(String farmId, FarmProfile updatedFarm) async {
    final farms = await loadFarms();
    final idx = farms.indexWhere((f) => f.farmId == farmId);
    if (idx >= 0) {
      farms[idx] = updatedFarm;
      await saveFarms(farms);
    }
  }

  Future<void> deleteFarm(String farmId) async {
    final farms = await loadFarms();
    farms.removeWhere((f) => f.farmId == farmId);
    await saveFarms(farms);
  }

  /// Returns the locally cached farms immediately without waiting on Firestore.
  /// Used by latency-sensitive UI paths such as AI Chat; [loadFarms] continues
  /// to refresh the cache from Firestore in the background elsewhere.
  Future<List<FarmProfile>> loadCachedFarms() => _loadCachedFarms();

  Future<List<FarmProfile>> _loadCachedFarms() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cached_farms');
    if (data != null) {
      try {
        final list = json.decode(data) as List;
        return list.map((m) => FarmProfile.fromMap(m)).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> _cacheFarms(List<FarmProfile> farms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'cached_farms', json.encode(farms.map((f) => f.toMap()).toList()));
  }

  // ==================== CROPS ====================

  Future<List<CropRecord>> loadCrops(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('crops')
            .where('farmId', isEqualTo: farmId)
            .get();
        return snap.docs.map((d) => CropRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    return _loadCachedCrops(farmId);
  }

  Future<void> saveCrop(CropRecord crop) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('crops')
            .doc(crop.id)
            .set(crop.toMap());
      } catch (_) {}
    }
    await _cacheCropLocally(crop);
  }

  Future<void> deleteCrop(String cropId) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('crops')
          .doc(cropId)
          .delete();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('crops_'));
    for (final key in keys) {
      final existing = prefs.getString(key) ?? '[]';
      final list = (json.decode(existing) as List)
          .where((m) => m['id'] != cropId)
          .toList();
      await prefs.setString(key, json.encode(list));
    }
  }

  Future<void> _cacheCropLocally(CropRecord crop) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'crops_${crop.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != crop.id)
        .toList();
    list.insert(0, crop.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<List<CropRecord>> _loadCachedCrops(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('crops_$farmId');
    if (data != null) {
      try {
        return (json.decode(data) as List)
            .map((m) => CropRecord.fromMap(m))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  /// Ends an active crop, moving it into the farm crop history. The record is
  /// kept in the same `crops` collection so it remains in the farm's history.
  Future<void> endCrop(
    CropRecord crop, {
    required String endStatus,
    String? reason,
    String? notes,
  }) async {
    final updated = crop.copyWith(
      status: endStatus,
      endReason: reason,
      endDate: DateTime.now(),
      notes: notes ?? crop.notes,
    );
    await saveCrop(updated);
  }

  // ==================== CROP PLANS ====================

  Future<void> saveCropPlan(CropPlan plan) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('crop_plans')
            .doc(plan.cropId)
            .set(plan.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'crop_plan_${plan.cropId}', json.encode(plan.toMap()));
  }

  Future<CropPlan?> loadCropPlan(String cropId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('crop_plans')
            .doc(cropId)
            .get();
        if (doc.exists && doc.data() != null) {
          final plan = CropPlan.fromMap(doc.data()!);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('crop_plan_$cropId', json.encode(plan.toMap()));
          return plan;
        }
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('crop_plan_$cropId');
    if (data != null) {
      try {
        return CropPlan.fromMap(json.decode(data));
      } catch (_) {}
    }
    return null;
  }

  // ==================== CROP TASKS (to-do) ====================

  Future<void> saveCropTask(CropTask task) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('crops')
            .doc(task.cropId)
            .collection('tasks')
            .doc(task.id)
            .set(task.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'crop_tasks_${task.cropId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != task.id)
        .toList();
    list.add(task.toMap());
    list.sort((a, b) => (a['dueDate'] ?? '')
        .toString()
        .compareTo((b['dueDate'] ?? '').toString()));
    await prefs.setString(key, json.encode(list));
  }

  Future<void> saveCropTasks(List<CropTask> tasks) async {
    for (final t in tasks) {
      await saveCropTask(t);
    }
  }

  Future<List<CropTask>> loadCropTasks(String cropId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('crops')
            .doc(cropId)
            .collection('tasks')
            .orderBy('dueDate')
            .get();
        final tasks = snap.docs.map((d) => CropTask.fromMap(d.data())).toList();
        if (tasks.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('crop_tasks_$cropId',
              json.encode(tasks.map((t) => t.toMap()).toList()));
          return tasks;
        }
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('crop_tasks_$cropId') ?? '[]';
    try {
      return (json.decode(data) as List)
          .map((m) => CropTask.fromMap(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> completeCropTask(String cropId, String taskId,
      {bool done = true}) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('crops')
            .doc(cropId)
            .collection('tasks')
            .doc(taskId)
            .update({
          'status': done ? 'done' : 'pending',
          'doneAt': done ? DateTime.now().toIso8601String() : null
        });
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'crop_tasks_$cropId';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
    for (final item in list) {
      if (item['id'] == taskId) {
        item['status'] = done ? 'done' : 'pending';
        break;
      }
    }
    await prefs.setString(key, json.encode(list));
  }

  // ==================== RECOMMENDATION RUNS ====================

  Future<void> saveRecommendationRecord(RecommendationRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('crop_recommendations')
            .doc(record.id)
            .set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'crop_recommendations_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != record.id)
        .toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<List<RecommendationRecord>> loadRecommendationRecords(
      String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('crop_recommendations')
            .where('farmId', isEqualTo: farmId)
            .orderBy('createdAt', descending: true)
            .get();
        final records = snap.docs
            .map((d) => RecommendationRecord.fromMap(d.data()))
            .toList();
        if (records.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('crop_recommendations_$farmId',
              json.encode(records.map((r) => r.toMap()).toList()));
          return records;
        }
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('crop_recommendations_$farmId') ?? '[]';
    try {
      return (json.decode(data) as List)
          .map((m) => RecommendationRecord.fromMap(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==================== MANUAL CROP CHECKS ====================

  Future<void> saveManualCropCheck(ManualCropCheck check) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('crop_manual_checks')
            .doc(check.id)
            .set(check.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'crop_manual_checks_${check.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != check.id)
        .toList();
    list.insert(0, check.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<List<ManualCropCheck>> loadManualCropChecks(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('crop_manual_checks')
            .where('farmId', isEqualTo: farmId)
            .orderBy('createdAt', descending: true)
            .get();
        final checks =
            snap.docs.map((d) => ManualCropCheck.fromMap(d.data())).toList();
        if (checks.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('crop_manual_checks_$farmId',
              json.encode(checks.map((c) => c.toMap()).toList()));
          return checks;
        }
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('crop_manual_checks_$farmId') ?? '[]';
    try {
      return (json.decode(data) as List)
          .map((m) => ManualCropCheck.fromMap(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==================== ALL CROPS (history across farms) ====================

  Future<List<CropRecord>> loadAllCrops() async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('crops')
            .orderBy('plantingDate', descending: true)
            .get();
        return snap.docs.map((d) => CropRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final seen = <String, CropRecord>{};
    for (final key in prefs.getKeys().where((k) => k.startsWith('crops_'))) {
      try {
        final list = json.decode(prefs.getString(key) ?? '[]') as List;
        for (final m in list) {
          final crop = CropRecord.fromMap(m);
          seen[crop.id] = crop;
        }
      } catch (_) {}
    }
    final crops = seen.values.toList()
      ..sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
    return crops;
  }

  // ==================== EXPENSES ====================

  Future<List<ExpenseRecord>> loadExpenses(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('expenses')
            .where('farmId', isEqualTo: farmId)
            .orderBy('date', descending: true)
            .get();
        return snap.docs.map((d) => ExpenseRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('expenses_$farmId') ?? '[]';
    return (json.decode(data) as List)
        .map((m) => ExpenseRecord.fromMap(m))
        .toList();
  }

  Future<void> saveExpense(ExpenseRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('expenses')
            .doc(record.id)
            .set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'expenses_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != record.id)
        .toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<void> deleteExpense(String id, String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('expenses')
            .doc(id)
            .delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'expenses_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    final list =
        (json.decode(existing) as List).where((m) => m['id'] != id).toList();
    await prefs.setString(key, json.encode(list));
  }

  // ==================== PESTICIDES ====================

  Future<List<PesticideRecord>> loadPesticides(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('pesticides')
            .where('farmId', isEqualTo: farmId)
            .orderBy('date', descending: true)
            .get();
        return snap.docs.map((d) => PesticideRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('pesticides_$farmId') ?? '[]';
    return (json.decode(data) as List)
        .map((m) => PesticideRecord.fromMap(m))
        .toList();
  }

  Future<void> savePesticide(PesticideRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('pesticides')
            .doc(record.id)
            .set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'pesticides_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != record.id)
        .toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<void> deletePesticide(String id, String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('pesticides')
            .doc(id)
            .delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'pesticides_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    final list =
        (json.decode(existing) as List).where((m) => m['id'] != id).toList();
    await prefs.setString(key, json.encode(list));
  }

  // ==================== FERTILIZERS ====================

  Future<List<FertilizerRecord>> loadFertilizers(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('fertilizers')
            .where('farmId', isEqualTo: farmId)
            .orderBy('date', descending: true)
            .get();
        return snap.docs
            .map((d) => FertilizerRecord.fromMap(d.data()))
            .toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('fertilizers_$farmId') ?? '[]';
    return (json.decode(data) as List)
        .map((m) => FertilizerRecord.fromMap(m))
        .toList();
  }

  Future<void> saveFertilizer(FertilizerRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('fertilizers')
            .doc(record.id)
            .set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'fertilizers_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != record.id)
        .toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<void> deleteFertilizer(String id, String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('fertilizers')
            .doc(id)
            .delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'fertilizers_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    final list =
        (json.decode(existing) as List).where((m) => m['id'] != id).toList();
    await prefs.setString(key, json.encode(list));
  }

  // ==================== DISEASE RECORDS ====================

  Future<List<DiseaseRecord>> loadDiseases(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('diseases')
            .where('farmId', isEqualTo: farmId)
            .orderBy('detectedDate', descending: true)
            .get();
        return snap.docs.map((d) => DiseaseRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('diseases_$farmId') ?? '[]';
    return (json.decode(data) as List)
        .map((m) => DiseaseRecord.fromMap(m))
        .toList();
  }

  Future<void> saveDisease(DiseaseRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('diseases')
            .doc(record.id)
            .set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'diseases_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List)
        .where((m) => m['id'] != record.id)
        .toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<void> deleteDisease(String id, String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('diseases')
            .doc(id)
            .delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'diseases_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    final list =
        (json.decode(existing) as List).where((m) => m['id'] != id).toList();
    await prefs.setString(key, json.encode(list));
  }

  // ==================== NOTIFICATIONS ====================

  Future<List<NotificationModel>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notification_history') ?? '[]';
    return (json.decode(data) as List)
        .map((m) => NotificationModel.fromMap(m))
        .toList();
  }

  Future<void> saveNotification(NotificationModel notification) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = json.decode(existing) as List;
    list.insert(0, notification.toMap());
    if (list.length > 200) list.removeLast();
    await prefs.setString('notification_history', json.encode(list));
  }

  Future<void> markNotificationRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = (json.decode(existing) as List)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    for (final item in list) {
      if (item['id'] == id) {
        item['isRead'] = true;
        break;
      }
    }
    await prefs.setString('notification_history', json.encode(list));
  }

  Future<void> markAllNotificationsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = (json.decode(existing) as List)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    for (final item in list) {
      item['isRead'] = true;
    }
    await prefs.setString('notification_history', json.encode(list));
  }

  Future<void> deleteNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = (json.decode(existing) as List)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    list.removeWhere((item) => item['id'] == id);
    await prefs.setString('notification_history', json.encode(list));
  }

  Future<int> getUnreadNotificationCount() async {
    final notifications = await loadNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  // ==================== PREFERENCES ====================

  Future<String> getSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_language') ?? 'en';
  }

  Future<void> setSelectedLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', code);
  }

  Future<String> getSelectedConsole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_domain') ?? 'farmer';
  }

  Future<void> setSelectedConsole(String console) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_domain', console);
  }

  // ==================== ACCENT COLOR ====================

  Future<int> getAccentColorIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('accent_color_index') ?? 0;
  }

  Future<void> setAccentColorIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color_index', index);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', value);
  }

  // ==================== HELPERS ====================

  String _safeErrorCode(Object error) {
    final text = error.toString();
    final match = RegExp(r'\[[a-z_]+/([a-z0-9_-]+)\]').firstMatch(text);
    if (match != null) return match.group(1) ?? error.runtimeType.toString();
    if (error is FirebaseException) return error.code;
    return error.runtimeType.toString();
  }

  String generateId() => _uuid.v4();

  // ==================== FULL RESTORE (after reinstall) ====================

  Future<UserProfile?> restoreFromBackend() async {
    final uid = _getUid();
    if (uid.isEmpty) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      final profile = UserProfile(
        uid: uid,
        email: data['email'] ?? '',
        displayName: data['displayName'] ?? '',
        gender: data['gender'] ?? '',
        dateOfBirth: data['dateOfBirth'] != null
            ? DateTime.tryParse(data['dateOfBirth'])
            : null,
        age: data['age'] ?? 0,
        address: data['address'] != null
            ? AddressData.fromMap(Map<String, dynamic>.from(data['address']))
            : null,
        avatarUrl: data['avatarUrl'] ?? '',
        role: data['role'] ?? 'farmer',
        isEmailVerified: data['isEmailVerified'] ?? false,
      );
      await _cacheProfile(profile);

      // Restore language
      if (data['selectedLanguage'] != null) {
        await setSelectedLanguage(data['selectedLanguage']);
      }
      // Restore console
      if (data['role'] != null) {
        await setSelectedConsole(data['role']);
      }

      // Restore farms
      final farmSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('farms')
          .orderBy('index')
          .get();
      final farms =
          farmSnap.docs.map((d) => FarmProfile.fromMap(d.data())).toList();
      if (farms.isNotEmpty) await _cacheFarms(farms);

      await setOnboardingComplete(true);
      return profile;
    } catch (_) {
      return null;
    }
  }
}
