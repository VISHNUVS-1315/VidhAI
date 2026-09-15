import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/app_config.dart';

class SecureApiException implements Exception {
  final String message;

  /// HTTP status returned by the backend, when available (e.g. 401 auth,
  /// 429 rate-limited, 5xx provider/backend).
  final int? statusCode;

  const SecureApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// POSTs JSON / multipart to the VidhAI secure backend using the current
/// Firebase ID token as Bearer auth. The client never holds AI keys.
class SecureApiClient {
  SecureApiClient._();
  static final SecureApiClient instance = SecureApiClient._();

  static const _baseUrl = AppConfig.aiBackendUrl;
  static const _timeout = Duration(seconds: 150);

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const SecureApiException('Not signed in.');
    }
    final token = await user.getIdToken(forceRefresh);
    if (token == null || token.isEmpty) {
      throw const SecureApiException('Could not obtain Firebase ID token.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? debugTag,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    if (debugTag != null) {
      debugPrint('[SecureApiClient:$debugTag] POST ${uri.toString()}');
    }

    Future<http.Response> send({bool forceRefresh = false}) async {
      final headers = await _authHeaders(forceRefresh: forceRefresh);
      return http
          .post(
            uri,
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    }

    var response = await send();
    if (response.statusCode == 401) {
      if (debugTag != null) {
        debugPrint(
            '[SecureApiClient:$debugTag] 401 received; forcing Firebase token refresh and retrying once.');
      }
      response = await send(forceRefresh: true);
    }

    if (debugTag != null) {
      debugPrint('[SecureApiClient:$debugTag] HTTP ${response.statusCode}');
      if (response.body.isNotEmpty) {
        debugPrint(
            '[SecureApiClient:$debugTag] body: ${response.body.length > 600 ? response.body.substring(0, 600) : response.body}');
      }
    }

    final decoded = _decode(response);
    if (decoded != null && debugTag != null) {
      debugPrint(
          '[SecureApiClient:$debugTag] decoded keys: ${decoded.keys.join(', ')}');
    }
    if (response.statusCode != 200) {
      throw SecureApiException(
        (decoded?['error'] as String?) ??
            'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return decoded ?? {};
  }

  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');

    Future<http.Response> send({bool forceRefresh = false}) async {
      final headers = await _authHeaders(forceRefresh: forceRefresh);
      return http.get(uri, headers: headers).timeout(_timeout);
    }

    var response = await send();
    if (response.statusCode == 401) {
      response = await send(forceRefresh: true);
    }

    final decoded = _decode(response);
    if (response.statusCode != 200) {
      throw SecureApiException(
        (decoded?['error'] as String?) ??
            'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return decoded ?? {};
  }

  /// Uploads a file (e.g. audio) with auth headers. `file` may be a path or bytes.
  Future<Map<String, dynamic>> postFile(
    String path, {
    required String field,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Map<String, String>? fields,
    String? debugTag,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');

    Future<http.Response> send({bool forceRefresh = false}) async {
      final headers = await _authHeaders(forceRefresh: forceRefresh);
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);
      if (fields != null) request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: filename,
        ),
      );
      final streamed = await request.send().timeout(_timeout);
      return http.Response.fromStream(streamed);
    }

    if (debugTag != null) {
      debugPrint('[SecureApiClient:$debugTag] POST ${uri.toString()}');
    }

    var response = await send();
    if (response.statusCode == 401) {
      if (debugTag != null) {
        debugPrint(
            '[SecureApiClient:$debugTag] 401 received; forcing Firebase token refresh and retrying upload once.');
      }
      response = await send(forceRefresh: true);
    }

    if (debugTag != null) {
      debugPrint('[SecureApiClient:$debugTag] HTTP ${response.statusCode}');
    }

    final decoded = _decode(response);
    if (response.statusCode != 200) {
      throw SecureApiException(
        (decoded?['error'] as String?) ??
            'Upload failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return decoded ?? {};
  }

  static Map<String, dynamic>? _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return {"data": decoded};
    } catch (_) {
      return {
        'error': response.body.length > 200 ? 'Server error.' : response.body
      };
    }
  }
}
