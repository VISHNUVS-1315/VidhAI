import 'package:http/http.dart' as http;
import 'package:vidhai/core/error/app_error.dart';
import 'package:vidhai/data/datasources/remote/remote_datasource.dart';
import 'dart:convert';

class RemoteDatasourceImpl implements RemoteDatasource {
  final http.Client _client = http.Client();

  @override
  Future<T> fetch<T>(String endpoint) async {
    final response = await _client.get(Uri.parse(endpoint));

    if (response.statusCode == 200) {
      return _handleResponse<T>(response);
    } else {
      throw AppError(
        message: 'Failed to load data from $endpoint',
        prefix: 'NetworkError',
      );
    }
  }

  @override
  Future<void> post(String endpoint, Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse(endpoint),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw AppError(
        message: 'Failed to post data to $endpoint',
        prefix: 'NetworkError',
      );
    }
  }

  T _handleResponse<T>(http.Response response) {
    final parsed = jsonDecode(response.body);

    if (T == int) return int.parse(parsed.toString()) as T;
    if (T == double) return double.parse(parsed.toString()) as T;
    if (T == String) return parsed as T;
    if (T == bool) return parsed as T;

    return parsed as T;
  }
}