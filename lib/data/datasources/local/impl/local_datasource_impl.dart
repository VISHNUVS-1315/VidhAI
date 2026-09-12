import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/datasources/local/local_datasource.dart';

class LocalDatasourceImpl implements LocalDatasource {
  final SharedPreferences _prefs;

  LocalDatasourceImpl(this._prefs);

  @override
  Future<T?> get<T>(String key) async {
    final value = _prefs.get(key);
    if (value == null) return null;
    return value as T;
  }

  @override
  Future<void> set(String key, dynamic value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    }
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }
}
