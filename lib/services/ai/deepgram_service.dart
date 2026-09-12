import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'secure_api_client.dart';

class DeepgramResult {
  final bool success;
  final String? text;
  final double? confidence;
  final String? error;
  final String provider;

  const DeepgramResult({
    this.success = false,
    this.text,
    this.confidence,
    this.error,
    this.provider = 'deepgram',
  });
}

/// Deepgram Nova-3 speech-to-text (STT).
///
/// Nova-3 understands Indian languages including Tamil, Telugu, Kannada,
/// Malayalam, Hindi, Marathi, Bengali, Gujarati, Punjabi, Odia, Malayalam,
/// Urdu and English, plus code-switched "Tanglish" speech. When a key is
/// compiled in via --dart-define=DEEPGRAM_API_KEY=... (test builds) this
/// service transcribes directly with Deepgram. No key and it must not be
/// called; WhisperService falls back to Groq/backend automatically.
class DeepgramService {
  DeepgramService._();
  static final DeepgramService instance = DeepgramService._();

  static final Uri _baseUri = Uri.parse('https://api.deepgram.com/v1/listen');
  static const Duration _timeout = Duration(seconds: 90);

  bool get isConfigured => AppConfig.deepgramApiKey.isNotEmpty;

  /// Builds the Nova-3 listen URL. Public + pure so unit tests can assert the
  /// wire format (model, smart_format, language, keyterms).
  static Uri buildListenUri({
    String language = 'en',
    List<String> keyterms = const [],
    Uri? baseUri,
  }) {
    final url = baseUri ?? _baseUri;
    final active = keyterms.where((t) => t.trim().isNotEmpty).toList();
    if (active.isEmpty) {
      final params = <String, String>{
        'model': AppConfig.deepgramModel,
        'smart_format': 'true',
        if (language.isNotEmpty) 'language': language,
      };
      return url.replace(queryParameters: params);
    }
    // Repeated `keyterm` params need a hand-built query string.
    final sb = StringBuffer()
      ..write('model=')
      ..write(Uri.encodeQueryComponent(AppConfig.deepgramModel))
      ..write('&smart_format=true');
    if (language.isNotEmpty) {
      sb
        ..write('&language=')
        ..write(Uri.encodeQueryComponent(language));
    }
    for (final term in active) {
      sb
        ..write('&keyterm=')
        ..write(Uri.encodeQueryComponent(term));
    }
    return Uri.parse('${url.toString()}?$sb');
  }

  /// Transcribes raw 16 kHz mono WAV bytes. Throws [SecureApiException] on an
  /// identifiable provider failure (returns nothing on generic transport
  /// errors via a failure [DeepgramResult]).
  Future<DeepgramResult> transcribe(
    List<int> wavBytes, {
    String? language,
    List<String> keyterms = const [],
  }) async {
    final apiKey = AppConfig.deepgramApiKey;
    if (apiKey.isEmpty) {
      return const DeepgramResult(error: 'Deepgram API key is not configured.');
    }

    final uri = buildListenUri(language: language ?? '', keyterms: keyterms);
    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Token $apiKey'
      ..headers['Content-Type'] = 'audio/wav'
      ..bodyBytes = wavBytes;

    try {
      final streamed = await http.Client().send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        throw SecureApiException(
          _describeError(response.statusCode),
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final json =
          decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      final alternatives =
          (json['results']?['channels']?[0]?['alternatives']) as List?;
      final first = alternatives == null || alternatives.isEmpty
          ? null
          : (alternatives.first as Map?);
      final text = first?['transcript'] as String? ?? '';
      final confidence = first?['confidence'] as num?;
      if (text.trim().isEmpty) {
        return const DeepgramResult(
            error: 'Could not understand the audio. Please try again.');
      }
      return DeepgramResult(
        success: true,
        text: text.trim(),
        confidence: confidence?.toDouble(),
      );
    } on SecureApiException {
      rethrow;
    } catch (_) {
      return const DeepgramResult(
          error: 'Deepgram request failed. Please check your connection.');
    }
  }

  String _describeError(int status) {
    if (status == 401 || status == 403) {
      return 'Invalid or missing Deepgram API key.';
    }
    if (status == 429) {
      return 'Deepgram rate limit reached. Try again in a moment.';
    }
    return 'Speech recognition failed (HTTP $status).';
  }
}
