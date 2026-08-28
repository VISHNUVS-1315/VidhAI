import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  LocalStorageService._();

  static SharedPreferences? _prefs;

  /// Initialize shared preferences
  static Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Check if preferences are initialized
  static bool get initialized => _prefs != null;

  /// Save string value
  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// Get string value
  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Save bool value
  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// Get bool value
  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  /// Save int value
  static Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  /// Get int value
  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  /// Save double value
  static Future<void> setDouble(String key, double value) async {
    await _prefs?.setDouble(key, value);
  }

  /// Get double value
  static double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  /// Save string list
  static Future<void> setStringList(String key, List<String> values) async {
    await _prefs?.setStringList(key, values);
  }

  /// Get string list
  static List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  /// Remove specific key
  static Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  /// Clear all preferences
  static Future<void> clear() async {
    await _prefs?.clear();
  }

  /// Check if key exists
  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }
}