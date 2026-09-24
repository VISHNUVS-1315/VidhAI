import 'dart:async';
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

  /// Reuse transports so repeated chat turns avoid a fresh DNS/TLS handshake.
  http.Client _regularClient = http.Client();
  http.Client? _streamClient;

  DateTime? _lastWarmUp;

  /// Starts waking the Render backend before the user sends a chat message.
  /// This is fire-and-forget by callers and never blocks the UI.
  Future<void> warmUp() async {
    final now = DateTime.now();
    final last = _lastWarmUp;
    if (last != null && now.difference(last) < const Duration(minutes: 10)) {
      return;
    }
    _lastWarmUp = now;

    try {
      await _regularClient
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // A sleeping free Render service can outlive this timeout; the request
      // still triggers its wake-up, which is the useful part.
    }
  }

  http.Client _newStreamClientIfNeeded() {
    return _streamClient ??= http.Client();
  }

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
      return _regularClient
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

  /// POSTs JSON and yields each parsed SSE `data:` event as it arrives.
  ///
  /// Used for the streaming AI chat path. A 401 triggers one Firebase token
  /// refresh + retry; any other non-200 throws [SecureApiException] before the
  /// stream starts. Cancelling the subscription (or [cancelActiveStream])
  /// aborts the underlying request.
  Stream<Map<String, dynamic>> postStream(
    String path,
    Map<String, dynamic> body, {
    String? debugTag,
    Duration? timeout,
  }) async* {
    final uri = Uri.parse('$_baseUrl$path');
    if (debugTag != null) {
      debugPrint('[SecureApiClient:$debugTag] POST stream ${uri.toString()}');
    }

    var forceRefresh = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      final client = _newStreamClientIfNeeded();

      http.StreamedResponse? response;
      try {
        final headers = await _authHeaders(forceRefresh: forceRefresh);
        final request = http.Request('POST', uri)
          ..headers.addAll({
            ...headers,
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode(body);
        response =
            await client.send(request).timeout(timeout ?? _timeout);
      } catch (e) {
        if (e is SecureApiException) rethrow;
        throw SecureApiException(
          'Network error (${e.runtimeType}).',
          statusCode: null,
        );
      }

      if (response.statusCode == 401 && attempt == 0) {
        if (debugTag != null) {
          debugPrint(
              '[SecureApiClient:$debugTag] 401 on stream; refreshing token and retrying once.');
        }
        forceRefresh = true;
        continue;
      }

      if (response.statusCode != 200) {
        String message = 'Request failed (${response.statusCode}).';
        try {
          final decoded = jsonDecode(
            utf8.decode(await response.stream.toBytes()),
          );
          if (decoded is Map && decoded['error'] is String) {
            message = decoded['error'] as String;
          }
        } catch (_) {}
        throw SecureApiException(
          message,
          statusCode: response.statusCode,
        );
      }

      yield* SecureApiClient.decodeSse(response.stream);
      return;
    }
    throw const SecureApiException(
      'Authorization failed (401).',
      statusCode: 401,
    );
  }

  /// Aborts any in-flight SSE stream opened by [postStream].
  void cancelActiveStream() {
    final client = _streamClient;
    _streamClient = null;
    client?.close();
  }

  /// Parses an SSE byte stream into individual `data:` JSON events.
  /// Malformed frames and the terminating `[DONE]` marker are skipped.
  static Stream<Map<String, dynamic>> decodeSse(
    Stream<List<int>> bytes,
  ) async* {
    final lines =
        bytes.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.isEmpty) continue;
      if (!line.startsWith('data:')) continue;
      final data = line.substring('data:'.length).trimLeft();
      if (data.isEmpty || data == '[DONE]') continue;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          yield decoded;
        } else if (decoded is Map) {
          yield Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Keep the stream alive across a malformed frame.
      }
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');

    Future<http.Response> send({bool forceRefresh = false}) async {
      final headers = await _authHeaders(forceRefresh: forceRefresh);
      return _regularClient.get(uri, headers: headers).timeout(_timeout);
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
      final streamed = await _regularClient.send(request).timeout(_timeout);
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
