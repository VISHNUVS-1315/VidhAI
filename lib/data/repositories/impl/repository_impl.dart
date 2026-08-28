import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:vidhai/core/error/app_error.dart';
import 'package:vidhai/data/datasources/local/local_datasource.dart';
import 'package:vidhai/data/datasources/remote/remote_datasource.dart';
import 'package:vidhai/data/repositories/repository.dart';

class RepositoryImpl implements Repository {
  final LocalDatasource localDatasource;
  final RemoteDatasource remoteDatasource;
  final Connectivity connectivity = Connectivity();

  RepositoryImpl({
    required this.localDatasource,
    required this.remoteDatasource,
  });

  @override
  Future<bool> get isConnected async {
    try {
      final results = await connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } on Exception {
      return false;
    }
  }

  @override
  Future<T> getData<T>(String key,
      {required Future<T> Function() fetchFromRemote}) async {
    // Try local first
    final localData = await localDatasource.get<T>(key);
    if (localData != null) {
      return localData;
    }

    // If not local, fetch from remote if connected
    if (await isConnected) {
      final remoteData = await fetchFromRemote();
      await localDatasource.set(key, remoteData);
      return remoteData;
    }

    // Offline with no local data
    throw AppError(
      message: 'No data available offline',
      prefix: 'OfflineError',
    );
  }

  @override
  Future<void> postData(String key, Map<String, dynamic> data,
      {required Future<void> Function(Map<String, dynamic>) saveToLocal}) async {
    // Post to remote first
    await remoteDatasource.post(key, data);

    // Then save to local
    await saveToLocal(data);
  }
}