import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/core/error/app_error.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _firebaseAuth.currentUser;
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  bool get hasValidSession {
    try {
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null || uid.isEmpty) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkEmailExists(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } on FirebaseException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> registerEmail(String email) async {
    final tempPassword = _generateTempPassword();

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      try {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'displayName': '',
          'role': '',
          'isEmailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        // Firestore write failed — proceed; onboarding will create doc later.
      }

      // Send real Firebase verification email (sends an actual email with link)
      try {
        await credential.user!.sendEmailVerification();
      } on FirebaseAuthException {
        // Non-critical; user can resend later.
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Email exists — sign in anonymously to get a user handle for verification
        final existing = await checkEmailExists(email);
        if (existing != null && existing['isEmailVerified'] == true) {
          return;
        }
        // Try to sign in to this account to send verification
        await _signInOrCreateForVerification(email, tempPassword);
        return;
      }
      if (e.code == 'invalid-email') {
        throw AppError(
          message: 'Please enter a valid email address.',
          prefix: 'AuthError',
        );
      }
      if (e.code == 'operation-not-allowed') {
        throw AppError(
          message:
              'Email sign-up is not available right now. Please try again later.',
          prefix: 'AuthError',
        );
      }
      throw AppError(
        message: _getAuthErrorMessage(e),
        prefix: 'AuthError',
      );
    } catch (e) {
      if (e is AppError) rethrow;
      throw AppError(
        message: 'Something went wrong. Please try again.',
        prefix: 'AuthError',
      );
    }
  }

  Future<void> _signInOrCreateForVerification(
      String email, String password) async {
    try {
      // Sign in to send verification email
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null && !credential.user!.emailVerified) {
        await credential.user!.sendEmailVerification();
      }
    } on FirebaseAuthException {
      // If sign-in fails (e.g. wrong password for existing account),
      // the user account exists but we can't access it. The verification
      // flow will still work via polling if they already have a user session.
    } catch (_) {
      // Non-critical
    }
  }

  Future<bool> checkIfEmailVerified() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      await user.reload();
      if (user.emailVerified) {
        // Update Firestore
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'isEmailVerified': true,
          }, SetOptions(merge: true));
        } on FirebaseException {
          // Non-critical
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException {
      // Rate limited or other error
      throw AppError(
        message: 'Could not send verification email. Please try again in a moment.',
        prefix: 'AuthError',
      );
    } catch (_) {
      throw AppError(
        message: 'Could not send verification email. Please try again.',
        prefix: 'AuthError',
      );
    }
  }

  Future<void> saveSession({
    required String email,
    required String displayName,
    required String role,
    required bool isEmailVerified,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _firebaseAuth.currentUser?.uid ?? '';
      await prefs.setString('user_uid', uid);
      await prefs.setString('user_email', email);
      await prefs.setString('user_display_name', displayName);
      await prefs.setString('selected_domain', role);
      await prefs.setBool('user_is_email_verified', isEmailVerified);
    } catch (_) {
      throw AppError(
        message: 'Failed to save session. Please try again.',
        prefix: 'SessionError',
      );
    }
  }

  Future<void> saveGuestSession({required String email}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setBool('email_skipped', true);
      await prefs.setBool('user_is_email_verified', false);
    } catch (_) {
      throw AppError(
        message: 'Failed to save session. Please try again.',
        prefix: 'SessionError',
      );
    }
  }

  Future<void> saveProfileToFirestore({
    required String email,
    required String fullName,
    required int age,
    required String gender,
    required String address,
    required String role,
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'displayName': fullName,
        'age': age,
        'gender': gender,
        'address': address,
        'role': role,
        'isEmailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_display_name', fullName);
      await prefs.setString('selected_domain', role);
    } catch (_) {
      throw AppError(
        message: 'Failed to save profile. Please try again.',
        prefix: 'ProfileError',
      );
    }
  }

  Future<void> saveFullProfile({
    required String email,
    required String fullName,
    required String gender,
    DateTime? dateOfBirth,
    required int age,
    Map<String, dynamic>? address,
    String? avatarUrl,
    required String role,
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_display_name', fullName);
    await prefs.setString('selected_domain', role);

    if (uid == null || uid.isEmpty) return;

    try {
      final data = <String, dynamic>{
        'uid': uid,
        'email': email,
        'displayName': fullName,
        'gender': gender,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'age': age,
        'role': role,
        'isEmailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (address != null) data['address'] = address;
      if (avatarUrl != null) data['avatarUrl'] = avatarUrl;

      await _firestore.collection('users').doc(uid).set(
            data,
            SetOptions(merge: true),
          );
    } catch (_) {
      // Firestore write failed; SP cache above is sufficient
    }
  }

  Future<void> saveFarmData({
    required List<Map<String, dynamic>> farms,
  }) async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).set({
        'farms': farms,
        'numberOfFarms': farms.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      throw AppError(
        message: 'Failed to save farm data. Please try again.',
        prefix: 'FarmError',
      );
    }
  }

  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('user_email');
      await prefs.remove('user_display_name');
      await prefs.remove('user_is_email_verified');
      await prefs.remove('email_skipped');
      await prefs.setBool('onboarding_complete', false);
      await prefs.remove('cached_farms');
      await prefs.remove('cached_profile');
    } catch (_) {
      throw AppError(
        message: 'Failed to log out. Please try again.',
        prefix: 'AuthError',
      );
    }
  }

  String _generateTempPassword() {
    final random = Random.secure();
    final chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'operation-not-allowed':
        return 'Email sign-up is not available right now. Please try again later.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
