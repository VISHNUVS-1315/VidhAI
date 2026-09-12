import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final List<ConnectivityResult> results =
          await _connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } on Exception {
      return false;
    }
  }

  /// Listen to connectivity changes
  static Stream<List<ConnectivityResult>> onConnectivityChanged() {
    return _connectivity.onConnectivityChanged.asBroadcastStream();
  }

  /// Get current connection type
  static Future<List<ConnectivityResult>> getCurrentConnection() async {
    return _connectivity.checkConnectivity();
  }

  /// Check if specific type of connection is available
  static Future<bool> hasWiFi() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r == ConnectivityResult.wifi);
  }

  static Future<bool> hasMobileData() async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) => r == ConnectivityResult.mobile);
  }
}
