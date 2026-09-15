import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../../../core/config/app_config.dart';
import 'deepgram_service.dart';
import 'secure_api_client.dart';

class WhisperResult {
  final bool success;
  final String? text;
  final String? error;

  /// Which engine produced the transcript: 'deepgram', 'groq-whisper', or
  /// the secure backend proxy. Null when nothing was transcribed.
  final String? provider;

  const WhisperResult(
      {this.success = false, this.text, this.error, this.provider});
}

/// Contract for capturing one spoken clip and transcribing it. Kept as an
/// interface so the voice conversation engine can be unit-tested with a fake
/// capturer instead of the real microphone / Whisper round-trip.
abstract class VoiceCapturer {
  /// Live mic amplitude in dBFS while recording (0 = max, <=-120 = silence).
  Stream<double> get onAmplitude;

  Future<bool> get isRecording;

  Future<bool> hasPermission();

  Future<bool> startRecording();

  Future<WhisperResult> stopAndTranscribe({String? language});

  Future<void> cancel();
}

/// Records short audio clips on-device and transcribes them with
/// OpenAI Whisper Large V3 Turbo via the secure backend.
///
/// While recording it exposes a live, normalized mic amplitude [onAmplitude]
/// (dBFS) so callers can visualise a wave and auto-end the clip after a short
/// silence (short-phrase mode).
class WhisperService implements VoiceCapturer {
  WhisperService._();
  static final WhisperService instance = WhisperService._();

  final AudioRecorder _recorder = AudioRecorder();
  final SecureApiClient _client = SecureApiClient.instance;
  String? _currentPath;
  final StreamController<double> _amplitude = StreamController.broadcast();
  StreamSubscription<Amplitude>? _ampSub;

  /// Live mic amplitude in dBFS while recording (0 = max, <=-120 = silence).
  /// Emits only while a clip is actually being recorded.
  @override
  Stream<double> get onAmplitude => _amplitude.stream;

  @override
  Future<bool> get isRecording => _recorder.isRecording();

  bool get _hasCurrentPath => _currentPath != null;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<bool> startRecording() async {
    if (await _recorder.isRecording()) return false;
    try {
      final dir = Directory.systemTemp;
      _currentPath =
          '${dir.path}${Platform.pathSeparator}vidhai_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentPath!,
      );
      _startAmplitudeStream();
      return true;
    } catch (_) {
      _currentPath = null;
      return false;
    }
  }

  /// Bridges the recorder's amplitude monitor to our broadcast stream.
  void _startAmplitudeStream() {
    _ampSub?.cancel();
    _ampSub =
        _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen(
      (Amplitude amp) {
        if (_amplitude.isClosed) return;
        final db = amp.current;
        _amplitude.add(db.isFinite ? db : -120);
      },
      onError: (_) {},
    );
  }

  @override
  Future<WhisperResult> stopAndTranscribe({String? language}) async {
    final path = _currentPath;
    if (path == null || !_hasCurrentPath) {
      return const WhisperResult(error: 'No recording to transcribe.');
    }
    _currentPath = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        return const WhisperResult(error: 'Recording was empty.');
      }
      final bytes = await file.readAsBytes();
      final Map<String, dynamic> json;
      final String? sttProvider;

      // 1) Primary: Deepgram Nova-3 (when a key is compiled in for test
      //    builds). Any failure falls through to Groq/backend so speech input
      //    still works even when Deepgram is unavailable or mis-keyed.
      final deepgramKit = await _tryDeepgram(bytes, language: language);
      if (deepgramKit != null) {
        await _tryDelete(path);
        return WhisperResult(
          success: true,
          text: deepgramKit.text,
          provider: 'deepgram',
        );
      }

      // 2) Fallback: Groq Whisper direct (test builds) or the secure backend.
      if (AppConfig.groqApiKey.isNotEmpty) {
        json = await _transcribeGroqDirect(bytes, language: language);
        sttProvider = 'groq-whisper';
      } else {
        json = await _client.postFile(
          '/ai/stt',
          field: 'audio',
          filename: 'recording.wav',
          contentType: 'audio/wav',
          bytes: bytes,
          fields: {
            if (language != null && language.isNotEmpty) 'language': language,
          },
          debugTag: 'STT',
        );
        sttProvider = 'backend';
      }
      final text = json['text'];
      await _tryDelete(path);
      if (text is String && text.trim().isNotEmpty) {
        return WhisperResult(
            success: true, text: text.trim(), provider: sttProvider);
      }
      return const WhisperResult(
          error: 'Could not understand the audio. Please try again.');
    } catch (e) {
      await _tryDelete(path);
      return WhisperResult(
        error: e is SecureApiException
            ? e.message
            : 'Voice input failed. Please try again.',
      );
    }
  }

  /// Transcribes directly with the Groq Whisper model when a key was compiled
  /// in via --dart-define (test builds). Never logs the key.
  Future<Map<String, dynamic>> _transcribeGroqDirect(
    List<int> bytes, {
    String? language,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
    );
    request.headers['Authorization'] = 'Bearer ${AppConfig.groqApiKey}';
    request.fields['model'] = 'whisper-large-v3-turbo';
    if (language != null && language.isNotEmpty) {
      request.fields['language'] = language;
    }
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'recording.wav',
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    debugPrint('[VidhAI] direct STT — HTTP ${response.statusCode}');
    if (response.statusCode != 200) {
      final hint = response.statusCode == 401 || response.statusCode == 403
          ? 'Invalid or missing Groq API key.'
          : response.statusCode == 429
              ? 'Groq rate limit reached. Try again in a moment.'
              : 'Speech recognition failed (HTTP ${response.statusCode}).';
      throw SecureApiException(hint, statusCode: response.statusCode);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// Best-effort Deepgram transcription. Returns null when Deepgram is
  /// unconfigured or fails so the caller continues down the STT chain.
  Future<({String text, double confidence})?> _tryDeepgram(
    List<int> bytes, {
    String? language,
  }) async {
    if (!DeepgramService.instance.isConfigured) return null;
    try {
      final result =
          await DeepgramService.instance.transcribe(bytes, language: language);
      if (result.success && (result.text ?? '').trim().isNotEmpty) {
        return (text: result.text!.trim(), confidence: result.confidence ?? 0);
      }
    } catch (e) {
      debugPrint(
          '[VidhAI] Deepgram STT failed — falling back. ${e.runtimeType}'); // SAFE: no secrets
    }
    return null;
  }

  @override
  Future<void> cancel() async {
    withAmplitudeSubscriptionCancel();
    if (await _recorder.isRecording()) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    final path = _currentPath;
    _currentPath = null;
    if (path != null) await _tryDelete(path);
  }

  /// Stops forwarding amplitude values (used when a clip ends or is dropped).
  Future<void> withAmplitudeSubscriptionCancel() async {
    await _ampSub?.cancel();
    _ampSub = null;
  }

  Future<void> dispose() {
    withAmplitudeSubscriptionCancel();
    _amplitude.close();
    return _recorder.dispose();
  }

  Future<void> _tryDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
