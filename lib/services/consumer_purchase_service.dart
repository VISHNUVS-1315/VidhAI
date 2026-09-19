import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ConsumerPurchaseRecord {
  final String id;
  final String commodity;
  final double quantityKg;
  final double pricePerKg;
  final double totalAmount;
  final String sellerName;
  final String market;
  final DateTime purchasedAt;
  final String status;
  final String notes;

  const ConsumerPurchaseRecord({
    required this.id,
    required this.commodity,
    required this.quantityKg,
    required this.pricePerKg,
    required this.totalAmount,
    required this.sellerName,
    required this.market,
    required this.purchasedAt,
    required this.status,
    required this.notes,
  });

  factory ConsumerPurchaseRecord.fromMap(Map<String, dynamic> map) {
    double number(Object? value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawDate = map['purchasedAt'];
    DateTime purchasedAt = DateTime.now();
    if (rawDate is Timestamp) {
      purchasedAt = rawDate.toDate();
    } else if (rawDate is String) {
      purchasedAt = DateTime.tryParse(rawDate) ?? purchasedAt;
    }

    return ConsumerPurchaseRecord(
      id: (map['id'] ?? '').toString(),
      commodity: (map['commodity'] ?? '').toString(),
      quantityKg: number(map['quantityKg']),
      pricePerKg: number(map['pricePerKg']),
      totalAmount: number(map['totalAmount']),
      sellerName: (map['sellerName'] ?? '').toString(),
      market: (map['market'] ?? '').toString(),
      purchasedAt: purchasedAt,
      status: (map['status'] ?? 'completed').toString(),
      notes: (map['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap({bool firestore = false}) => {
        'id': id,
        'commodity': commodity,
        'quantityKg': quantityKg,
        'pricePerKg': pricePerKg,
        'totalAmount': totalAmount,
        'sellerName': sellerName,
        'market': market,
        'purchasedAt':
            firestore ? Timestamp.fromDate(purchasedAt) : purchasedAt.toIso8601String(),
        'status': status,
        'notes': notes,
      };
}

/// Consumer purchase persistence.
///
/// The current app does not fabricate transactions. Records only appear after
/// a real purchase flow calls [recordPurchase]. Until then Purchase History
/// honestly shows an empty state.
class ConsumerPurchaseService {
  ConsumerPurchaseService._();
  static final ConsumerPurchaseService instance = ConsumerPurchaseService._();

  static const _cacheKey = 'consumer_purchase_history_v1';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  Future<List<ConsumerPurchaseRecord>> loadPurchases() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('users')
            .doc(uid)
            .collection('purchases')
            .orderBy('purchasedAt', descending: true)
            .limit(200)
            .get();
        final records = snap.docs
            .map((doc) => ConsumerPurchaseRecord.fromMap({
                  ...doc.data(),
                  'id': doc.data()['id'] ?? doc.id,
                }))
            .toList();
        await _cache(records);
        return records;
      } catch (_) {
        // Fall through to the last locally cached purchase history.
      }
    }
    return _readCache();
  }

  Future<ConsumerPurchaseRecord> recordPurchase({
    required String commodity,
    required double quantityKg,
    required double pricePerKg,
    String sellerName = '',
    String market = '',
    String notes = '',
    String status = 'completed',
    DateTime? purchasedAt,
  }) async {
    final record = ConsumerPurchaseRecord(
      id: _uuid.v4(),
      commodity: commodity.trim(),
      quantityKg: quantityKg,
      pricePerKg: pricePerKg,
      totalAmount: quantityKg * pricePerKg,
      sellerName: sellerName.trim(),
      market: market.trim(),
      purchasedAt: purchasedAt ?? DateTime.now(),
      status: status,
      notes: notes.trim(),
    );

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('purchases')
          .doc(record.id)
          .set(record.toMap(firestore: true));
    }

    final current = await _readCache();
    await _cache([record, ...current.where((item) => item.id != record.id)]);
    return record;
  }

  Future<void> _cache(List<ConsumerPurchaseRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(records.map((record) => record.toMap()).toList()),
    );
  }

  Future<List<ConsumerPurchaseRecord>> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => ConsumerPurchaseRecord.fromMap(
                Map<String, dynamic>.from(item.cast<String, dynamic>()),
              ))
          .toList()
        ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    } catch (_) {
      return const [];
    }
  }
}
