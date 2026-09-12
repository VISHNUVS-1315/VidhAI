import 'package:shared_preferences/shared_preferences.dart';

class AuthLocalDatasource {
  final SharedPreferences _prefs;

  AuthLocalDatasource(this._prefs);

  /// Save user session
  Future<void> saveUser({
    required String uid,
    required String email,
    required String displayName,
    required bool isEmailVerified,
  }) async {
    await _prefs.setString('user_uid', uid);
    await _prefs.setString('user_email', email);
    await _prefs.setString('user_display_name', displayName);
    await _prefs.setBool('user_is_email_verified', isEmailVerified);
  }

  /// Get user session
  Map<String, dynamic>? getUser({
    required String uid,
  }) {
    final email = _prefs.getString('user_email');
    final displayName = _prefs.getString('user_display_name');
    final isEmailVerified = _prefs.getBool('user_is_email_verified');

    if (uid.isEmpty) return null;

    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'isEmailVerified': isEmailVerified,
    };
  }

  /// Clear user session
  Future<void> clearUser() async {
    await _prefs.remove('user_uid');
    await _prefs.remove('user_email');
    await _prefs.remove('user_display_name');
    await _prefs.remove('user_is_email_verified');
  }

  /// Check if user has active session
  bool get hasActiveSession {
    final uid = _prefs.getString('user_uid');
    return uid != null && uid.isNotEmpty;
  }
}
