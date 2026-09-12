abstract class Repository {
  Future<bool> get isConnected;

  Future<T> getData<T>(String key,
      {required Future<T> Function() fetchFromRemote});

  Future<void> postData(String key, Map<String, dynamic> data,
      {required Future<void> Function(Map<String, dynamic>) saveToLocal});
}
