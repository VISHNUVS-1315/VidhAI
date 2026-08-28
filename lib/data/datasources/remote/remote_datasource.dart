abstract class RemoteDatasource {
  Future<T> fetch<T>(String endpoint);

  Future<void> post(String endpoint, Map<String, dynamic> data);
}