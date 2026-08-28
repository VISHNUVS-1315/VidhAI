import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vidhai/core/error/app_error.dart';

class OnboardingRemoteDatasource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save onboarding data for user
  Future<void> saveOnboardingData({
    required String userId,
    required String fullName,
    required int age,
    required String gender,
    required String address,
    required String role,
  }) async {
    try {
      final userDoc = _db.collection('users').doc(userId);

      // Check if user already exists to avoid duplicates
      final snapshot = await userDoc.get();
      if (snapshot.exists) {
        // Update existing user data
        await userDoc.update({
          'fullName': fullName,
          'age': age,
          'gender': gender,
          'address': address,
          'role': role,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new user document
        await userDoc.set({
          'uid': userId,
          'fullName': fullName,
          'age': age,
          'gender': gender,
          'email': '', // Will be filled from auth
          'address': address,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } on FirebaseException catch (e) {
      throw AppError(
        message: 'Failed to save onboarding data: ${e.message}',
        prefix: 'DatabaseError',
      );
    } catch (e) {
      throw AppError(
        message: 'An unexpected error occurred',
        prefix: 'Error',
      );
    }
  }

  /// Get onboarding data for user
  Future<Map<String, dynamic>?> getOnboardingData(String userId) async {
    try {
      final snapshot = await _db.collection('users').doc(userId).get();
      if (snapshot.exists) {
        return snapshot.data() as Map<String, dynamic>;
      }
      return null;
    } on FirebaseException catch (e) {
      throw AppError(
        message: 'Failed to fetch onboarding data: ${e.message}',
        prefix: 'DatabaseError',
      );
    } catch (e) {
      throw AppError(
        message: 'An unexpected error occurred',
        prefix: 'Error',
      );
    }
  }
}