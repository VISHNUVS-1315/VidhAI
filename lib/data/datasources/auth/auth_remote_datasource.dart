import 'package:firebase_auth/firebase_auth.dart';
import 'package:vidhai/core/error/app_error.dart';

class AuthRemoteDatasource {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Get current user uid
  String? get userId => _auth.currentUser?.uid;

  /// Get current user email
  String? get userEmail => _auth.currentUser?.email;

  /// Get current user display name
  String? get userDisplayName => _auth.currentUser?.displayName;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AppError(
        message: _getAuthErrorMessage(e),
        prefix: 'AuthError',
      );
    } catch (e) {
      throw AppError(
        message: 'An unexpected error occurred',
        prefix: 'Error',
      );
    }
  }

  /// Register with email and password
  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      if (displayName.isNotEmpty) {
        await userCredential.user!.updateDisplayName(displayName);
      }
      
      // Send verification email
      await userCredential.user!.sendEmailVerification();
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AppError(
        message: _getAuthErrorMessage(e),
        prefix: 'AuthError',
      );
    } catch (e) {
      throw AppError(
        message: 'An unexpected error occurred',
        prefix: 'Error',
      );
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser!.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AppError(
        message: _getAuthErrorMessage(e),
        prefix: 'AuthError',
      );
    } catch (e) {
      throw AppError(
        message: 'Failed to send verification email',
        prefix: 'Error',
      );
    }
  }

  /// Resend email verification
  Future<void> resendEmailVerification() async {
    try {
      await _auth.currentUser!.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AppError(
        message: _getAuthErrorMessage(e),
        prefix: 'AuthError',
      );
    } catch (e) {
      throw AppError(
        message: 'Failed to resend verification email',
        prefix: 'Error',
      );
    }
  }

  /// Forget password
  Future<void> forgetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AppError(
        message: _getAuthErrorMessage(e),
        prefix: 'AuthError',
      );
    } catch (e) {
      throw AppError(
        message: 'Failed to send password reset email',
        prefix: 'Error',
      );
    }
  }

  /// Log out
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Get auth error message
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password provided';
      case 'user-disabled':
        return 'This user account has been disabled';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'Account already exists with this email';
      case 'operation-not-allowed':
        return 'Operation not allowed';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}