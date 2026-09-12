import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/core/error/app_error.dart';

class GoogleSignInResult {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final bool onboardingComplete;

  const GoogleSignInResult({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.onboardingComplete,
  });
}

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Web (server) OAuth client from android/app/google-services.json
  /// (client_type: 3). Used as the serverClientId for the Google Credential
  /// Manager ID-token request. Do NOT replace with an Android client id.
  static const String _googleWebClientId =
      '750262338889-cjg5g8jovjsu5igfp22c8c7nhcr26bud.apps.googleusercontent.com';

  /// Single shared Google Sign-In instance. Everything (the login screen and
  /// sign-out) routes through this one instance so no duplicate plumbing exists.
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

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

  /// Signs in with Google.
  ///
  /// The flow is the standard 7.x google_sign_in flow:
  ///   initialize() exactly once -> authenticate() (Android account chooser)
  ///   -> obtain idToken -> FirebaseAuth.signInWithCredential()
  ///   -> sync Google profile to Firestore `users/{uid}` (merge semantics).
  ///
  /// Real errors are logged locally (type/code/description, never tokens); the
  /// user only ever sees a clean, localized message.
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      if (!_googleSignInInitialized) {
        await _googleSignIn.initialize(
          serverClientId: _googleWebClientId,
        );
        _googleSignInInitialized = true;
      }

      // Presents the Android Google account chooser on every fresh sign-in.
      final GoogleSignInAccount account = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = account.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('GoogleSignIn missing idToken from authenticate()');
        throw AppError(message: 'google-sign-in-config-error');
      }

      final AuthCredential credential =
          GoogleAuthProvider.credential(idToken: idToken);
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user == null) {
        throw AppError(message: 'google-sign-in-failed');
      }

      final uid = user.uid;
      final email = user.email ?? '';
      final displayName = user.displayName ?? '';
      final photoUrl = user.photoURL;

      Map<String, dynamic>? existingDoc;
      try {
        final snapshot = await _firestore.collection('users').doc(uid).get();
        if (snapshot.exists) existingDoc = snapshot.data();
      } catch (_) {
        // Firestore read failed; continue as a new-user merge below.
      }

      final existingUser = existingDoc != null &&
          ((existingDoc['displayName'] as String?) ?? '').isNotEmpty;
      final role = existingUser ? ((existingDoc['role'] as String?) ?? '') : '';

      // Sync Google account info to Firestore (merge keeps onboarded data).
      final data = <String, dynamic>{
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role,
        'isEmailVerified': true,
        'authProvider': 'google',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (photoUrl != null && photoUrl.isNotEmpty) {
        data['photoUrl'] = photoUrl;
      }
      if (existingDoc == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .set(data, SetOptions(merge: true));
      } catch (_) {
        // Firestore write failed; the local session below is the fallback.
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', uid);
      await prefs.setString('user_email', email);
      await prefs.setString('user_display_name', displayName);
      if (role.isNotEmpty) await prefs.setString('selected_domain', role);
      await prefs.setBool('user_is_email_verified', true);

      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      return GoogleSignInResult(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        onboardingComplete: onboardingComplete,
      );
    } on GoogleSignInException catch (e) {
      debugPrint(
          'GoogleSignIn GoogleSignInException code=${e.code.name} description=${e.description} details=${e.details}');
      throw AppError(
          message: _classifyGoogleSignException(e.code, e.description));
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'GoogleSignIn FirebaseAuthException type=${e.runtimeType} code=${e.code} msg=${e.message} credential=${e.credential?.providerId}');
      throw AppError(message: _classifyFirebaseSignInError(e.code));
    } on PlatformException catch (e) {
      debugPrint(
          'GoogleSignIn PlatformException type=${e.runtimeType} code=${e.code} details=${e.details}');
      throw AppError(message: _classifyPlatformSignInError(e.code));
    } on AppError {
      rethrow;
    } catch (e) {
      debugPrint('GoogleSignIn unknown error type=${e.runtimeType} error=$e');
      throw AppError(message: 'google-sign-in-failed');
    }
  }

  String _classifyGoogleSignException(
      GoogleSignInExceptionCode code, String? description) {
    final desc = (description ?? '').toLowerCase();
    switch (code) {
      case GoogleSignInExceptionCode.canceled:
      case GoogleSignInExceptionCode.interrupted:
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'google-sign-in-cancelled';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'google-sign-in-config-error';
      case GoogleSignInExceptionCode.userMismatch:
        return 'google-sign-in-failed';
      case GoogleSignInExceptionCode.unknownError:
        if (desc.contains('network') || desc.contains('host')) {
          return 'network-error';
        }
        return 'google-sign-in-failed';
    }
  }

  String _classifyFirebaseSignInError(String code) {
    switch (code) {
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'canceled':
      case 'user-cancelled':
        return 'google-sign-in-cancelled';
      case 'network-request-failed':
      case 'network-error':
        return 'network-error';
      case 'operation-not-allowed':
        return 'google-sign-in-not-enabled';
      case 'internal-error':
        return 'google-sign-in-config-error';
      case 'invalid-credential':
        return 'google-sign-in-config-error';
      default:
        return 'google-sign-in-failed';
    }
  }

  String _classifyPlatformSignInError(String code) {
    switch (code) {
      case 'sign_in_cancelled':
      case 'canceled':
        return 'google-sign-in-cancelled';
      case 'network_error':
        return 'network-error';
      case '10':
      case '12500':
      case '12501':
      case 'internal_error':
      case '4':
      case 'developer_error':
        return 'google-sign-in-config-error';
      default:
        return 'google-sign-in-failed';
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

  Future<void> logout() async {
    try {
      if (_googleSignInInitialized) {
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          debugPrint('GoogleSignIn signOut failed: $e');
        }
      }
      await _firebaseAuth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('user_email');
      await prefs.remove('user_display_name');
      await prefs.remove('user_is_email_verified');
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
}
