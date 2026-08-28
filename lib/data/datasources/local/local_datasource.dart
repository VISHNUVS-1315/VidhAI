abstract class LocalDatasource {
  Future<T?> get<T>(String key);

  Future<void> set(String key, dynamic value);

  Future<void> remove(String key);

  Future<void> clear();
}