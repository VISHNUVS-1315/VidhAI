import 'package:vidhai/data/datasources/onboarding/onboarding_local_datasource.dart';
import 'package:vidhai/data/datasources/onboarding/onboarding_remote_datasource.dart';

class OnboardingRepository {
  final OnboardingLocalDatasource _localDatasource;
  final OnboardingRemoteDatasource _remoteDatasource;

  OnboardingRepository(
    this._localDatasource,
    this._remoteDatasource,
  );

  /// Save onboarding data (both local and remote)
  Future<void> saveOnboardingData({
    required String fullName,
    required int age,
    required String gender,
    required String address,
    required String role,
    required String userId,
  }) async {
    // Save to local storage first (for offline persistence)
    await _localDatasource.saveOnboardingData(
      fullName: fullName,
      age: age,
      gender: gender,
      address: address,
      role: role,
    );

    // Save to remote database
    await _remoteDatasource.saveOnboardingData(
      userId: userId,
      fullName: fullName,
      age: age,
      gender: gender,
      address: address,
      role: role,
    );
  }

  /// Get onboarding data (check local first, then remote)
  Future<Map<String, dynamic>?> getOnboardingData(String userId) async {
    // Try local first
    final localData = _localDatasource.getOnboardingData();
    if (localData != null) {
      return localData;
    }

    // Fall back to remote
    return await _remoteDatasource.getOnboardingData(userId);
  }

  /// Check if onboarding is complete (has data locally)
  bool get isOnboardingComplete => _localDatasource.hasOnboardingData;
}
