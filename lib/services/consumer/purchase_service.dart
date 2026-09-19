import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Personal receipts. Interest/acceptance alone is never treated as a purchase.
class PurchaseService {
  static CollectionReference<Map<String, dynamic>> get records {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in required');
    return FirebaseFirestore.instance.collection('users').doc(uid).collection('purchases');
  }

  static Future<void> record({required String? accountId, required String postId, required String crop,
    required String seller, required double quantityKg, required double totalPaid}) async {
    if (accountId == null || FirebaseAuth.instance.currentUser?.uid != accountId) throw StateError('Account changed');
    if (!quantityKg.isFinite || quantityKg <= 0 || !totalPaid.isFinite || totalPaid < 0) {
      throw ArgumentError('Invalid purchase amounts');
    }
    // One receipt per completed post prevents duplicates after retries.
    final receipt = records.doc(postId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(receipt);
      if (existing.exists) return;
      transaction.set(receipt, {
      'postId': postId, 'crop': crop, 'seller': seller,
      'quantityKg': quantityKg, 'totalPaid': totalPaid,
      'completedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
