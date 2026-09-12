import 'package:shared_preferences/shared_preferences.dart';

class OnboardingLocalDatasource {
  final SharedPreferences _prefs;

  OnboardingLocalDatasource(this._prefs);

  /// Save onboarding data locally
  Future<void> saveOnboardingData({
    required String fullName,
    required int age,
    required String gender,
    required String address,
    required String role,
  }) async {
    await _prefs.setString('onboarding_fullName', fullName);
    await _prefs.setInt('onboarding_age', age);
    await _prefs.setString('onboarding_gender', gender);
    await _prefs.setString('onboarding_address', address);
    await _prefs.setString('onboarding_role', role);
  }

  /// Get onboarding data locally
  Map<String, dynamic>? getOnboardingData() {
    final fullName = _prefs.getString('onboarding_fullName');
    final age = _prefs.getInt('onboarding_age');
    final gender = _prefs.getString('onboarding_gender');
    final address = _prefs.getString('onboarding_address');
    final role = _prefs.getString('onboarding_role');

    if (fullName == null) return null;

    return {
      'fullName': fullName,
      'age': age,
      'gender': gender,
      'address': address,
      'role': role,
    };
  }

  /// Clear onboarding data locally
  Future<void> clearOnboardingData() async {
    await _prefs.remove('onboarding_fullName');
    await _prefs.remove('onboarding_age');
    await _prefs.remove('onboarding_gender');
    await _prefs.remove('onboarding_address');
    await _prefs.remove('onboarding_role');
  }

  /// Check if onboarding data exists locally
  bool get hasOnboardingData {
    final fullName = _prefs.getString('onboarding_fullName');
    return fullName != null && fullName.isNotEmpty;
  }
}
