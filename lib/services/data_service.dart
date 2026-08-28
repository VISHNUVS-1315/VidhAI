import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vidhai/data/models/user_profile.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/data/models/crop_models.dart';
import 'package:vidhai/data/models/farm_records.dart';
import 'package:vidhai/data/models/notification_model.dart';

class DataService {
  static final DataService _instance = DataService._();
  factory DataService() => _instance;
  DataService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  String _getUid() => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ==================== USER PROFILE ====================

  Future<UserProfile?> loadProfile() async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
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
          return profile;
        }
      } catch (_) {}
    }
    return _loadCachedProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _cacheProfile(profile);
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid).set(profile.toMap(), SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> _cacheProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_profile', json.encode(profile.toMap()));
  }

  UserProfile? _loadCachedProfile() {
    return null; // Will be populated from SharedPreferences by the caller
  }

  Future<UserProfile?> loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cached_profile');
    if (data != null) {
      try {
        return UserProfile.fromMap(json.decode(data));
      } catch (_) {}
    }
    // Fallback: build from individual SP keys
    final name = prefs.getString('user_display_name') ?? '';
    final email = prefs.getString('user_email') ?? '';
    if (name.isEmpty && email.isEmpty) return null;
    return UserProfile(
      uid: prefs.getString('user_uid') ?? '',
      email: email,
      displayName: name,
      role: prefs.getString('selected_domain') ?? 'farmer',
      isEmailVerified: prefs.getString('user_is_email_verified') == 'true',
    );
  }

  // ==================== FARMS ====================

  Future<List<FarmProfile>> loadFarms() async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore.collection('users').doc(uid)
            .collection('farms').orderBy('index').get();
        final farms = snap.docs.map((d) => FarmProfile.fromMap(d.data())).toList();
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
    debugPrint('[DataService] uid: ${uid.isEmpty ? "EMPTY" : uid.substring(0, uid.length > 8 ? 8 : uid.length)}');
    if (uid.isNotEmpty) {
      try {
        final farmCol = _firestore.collection('users').doc(uid).collection('farms');
        debugPrint('[DataService] Firestore: fetching existing farms...');
        final existing = await farmCol.get();
        debugPrint('[DataService] Firestore: ${existing.docs.length} existing docs');
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
    await prefs.setString('cached_farms', json.encode(farms.map((f) => f.toMap()).toList()));
  }

  // ==================== CROPS ====================

  Future<List<CropRecord>> loadCrops(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore.collection('users').doc(uid)
            .collection('crops').where('farmId', isEqualTo: farmId).get();
        return snap.docs.map((d) => CropRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    return _loadCachedCrops(farmId);
  }

  Future<void> saveCrop(CropRecord crop) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid)
            .collection('crops').doc(crop.id).set(crop.toMap());
      } catch (_) {}
    }
    await _cacheCropLocally(crop);
  }

  Future<void> deleteCrop(String cropId) async {
    final uid = _getUid();
    if (uid.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid)
          .collection('crops').doc(cropId).delete();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('crops_'));
    for (final key in keys) {
      final existing = prefs.getString(key) ?? '[]';
      final list = (json.decode(existing) as List).where((m) => m['id'] != cropId).toList();
      await prefs.setString(key, json.encode(list));
    }
  }

  Future<void> _cacheCropLocally(CropRecord crop) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'crops_${crop.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != crop.id).toList();
    list.insert(0, crop.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<List<CropRecord>> _loadCachedCrops(String farmId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('crops_$farmId');
    if (data != null) {
      try {
        return (json.decode(data) as List).map((m) => CropRecord.fromMap(m)).toList();
      } catch (_) {}
    }
    return [];
  }

  // ==================== EXPENSES ====================

  Future<List<ExpenseRecord>> loadExpenses(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore.collection('users').doc(uid)
            .collection('expenses').where('farmId', isEqualTo: farmId)
            .orderBy('date', descending: true).get();
        return snap.docs.map((d) => ExpenseRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('expenses_$farmId') ?? '[]';
    return (json.decode(data) as List).map((m) => ExpenseRecord.fromMap(m)).toList();
  }

  Future<void> saveExpense(ExpenseRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid)
            .collection('expenses').doc(record.id).set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'expenses_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != record.id).toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<void> deleteExpense(String id, String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid).collection('expenses').doc(id).delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'expenses_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != id).toList();
    await prefs.setString(key, json.encode(list));
  }

  // ==================== PESTICIDES ====================

  Future<List<PesticideRecord>> loadPesticides(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore.collection('users').doc(uid)
            .collection('pesticides').where('farmId', isEqualTo: farmId)
            .orderBy('date', descending: true).get();
        return snap.docs.map((d) => PesticideRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('pesticides_$farmId') ?? '[]';
    return (json.decode(data) as List).map((m) => PesticideRecord.fromMap(m)).toList();
  }

  Future<void> savePesticide(PesticideRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid)
            .collection('pesticides').doc(record.id).set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'pesticides_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != record.id).toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<void> deletePesticide(String id, String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid).collection('pesticides').doc(id).delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'pesticides_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != id).toList();
    await prefs.setString(key, json.encode(list));
  }

  // ==================== FERTILIZERS ====================

  Future<List<FertilizerRecord>> loadFertilizers(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore.collection('users').doc(uid)
            .collection('fertilizers').where('farmId', isEqualTo: farmId)
            .orderBy('date', descending: true).get();
        return snap.docs.map((d) => FertilizerRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('fertilizers_$farmId') ?? '[]';
    return (json.decode(data) as List).map((m) => FertilizerRecord.fromMap(m)).toList();
  }

  Future<void> saveFertilizer(FertilizerRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid)
            .collection('fertilizers').doc(record.id).set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'fertilizers_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != record.id).toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<void> deleteFertilizer(String id, String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid).collection('fertilizers').doc(id).delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'fertilizers_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != id).toList();
    await prefs.setString(key, json.encode(list));
  }

  // ==================== DISEASE RECORDS ====================

  Future<List<DiseaseRecord>> loadDiseases(String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore.collection('users').doc(uid)
            .collection('diseases').where('farmId', isEqualTo: farmId)
            .orderBy('detectedDate', descending: true).get();
        return snap.docs.map((d) => DiseaseRecord.fromMap(d.data())).toList();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('diseases_$farmId') ?? '[]';
    return (json.decode(data) as List).map((m) => DiseaseRecord.fromMap(m)).toList();
  }

  Future<void> saveDisease(DiseaseRecord record) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid)
            .collection('diseases').doc(record.id).set(record.toMap());
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'diseases_${record.farmId}';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != record.id).toList();
    list.insert(0, record.toMap());
    await prefs.setString(key, json.encode(list));
  }

  Future<void> deleteDisease(String id, String farmId) async {
    final uid = _getUid();
    if (uid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(uid).collection('diseases').doc(id).delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final key = 'diseases_$farmId';
    final existing = prefs.getString(key) ?? '[]';
    final list = (json.decode(existing) as List).where((m) => m['id'] != id).toList();
    await prefs.setString(key, json.encode(list));
  }

  // ==================== NOTIFICATIONS ====================

  Future<List<NotificationModel>> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('notification_history') ?? '[]';
    return (json.decode(data) as List).map((m) => NotificationModel.fromMap(m)).toList();
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
    final list = (json.decode(existing) as List).map((m) => Map<String, dynamic>.from(m)).toList();
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
    final list = (json.decode(existing) as List).map((m) => Map<String, dynamic>.from(m)).toList();
    for (final item in list) {
      item['isRead'] = true;
    }
    await prefs.setString('notification_history', json.encode(list));
  }

  Future<void> deleteNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('notification_history') ?? '[]';
    final list = (json.decode(existing) as List).map((m) => Map<String, dynamic>.from(m)).toList();
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

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', value);
  }

  // ==================== HELPERS ====================

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
        dateOfBirth: data['dateOfBirth'] != null ? DateTime.tryParse(data['dateOfBirth']) : null,
        age: data['age'] ?? 0,
        address: data['address'] != null ? AddressData.fromMap(Map<String, dynamic>.from(data['address'])) : null,
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
      final farmSnap = await _firestore.collection('users').doc(uid).collection('farms').orderBy('index').get();
      final farms = farmSnap.docs.map((d) => FarmProfile.fromMap(d.data())).toList();
      if (farms.isNotEmpty) await _cacheFarms(farms);

      await setOnboardingComplete(true);
      return profile;
    } catch (_) {
      return null;
    }
  }
}
