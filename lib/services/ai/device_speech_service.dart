import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceCaptureResult {
  final bool success;
  final String? text;
  final String? error;
  final String? provider;

  const VoiceCaptureResult({
    this.success = false,
    this.text,
    this.error,
    this.provider,
  });
}

/// Injectable contract used by chat/assistant/live-voice controllers.
abstract class VoiceCapturer {
  Stream<double> get onAmplitude;
  Stream<String> get onTranscript;
  Future<bool> get isRecording;
  Future<bool> hasPermission();
  Future<bool> startRecording({String? language});
  Future<VoiceCaptureResult> stopAndTranscribe({String? language});
  Future<void> cancel();
}

/// On-device speech recognition using Android/iOS platform speech services.
///
/// No third-party STT API key is stored or required by VidhAI.
class DeviceSpeechService implements VoiceCapturer {
  DeviceSpeechService._();
  static final DeviceSpeechService instance = DeviceSpeechService._();

  final SpeechToText _speech = SpeechToText();
  final StreamController<double> _amplitude =
      StreamController<double>.broadcast();
  final StreamController<String> _transcript =
      StreamController<String>.broadcast();

  bool _initialized = false;
  String _latestText = '';
  String? _lastError;

  @override
  Stream<double> get onAmplitude => _amplitude.stream;

  @override
  Stream<String> get onTranscript => _transcript.stream;

  @override
  Future<bool> get isRecording async => _speech.isListening;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onError: (error) {
        _lastError = error.errorMsg;
      },
      onStatus: (_) {},
      debugLogging: false,
    );
    return _initialized;
  }

  @override
  Future<bool> hasPermission() => _ensureInitialized();

  String _localeFor(String? language) {
    const map = <String, String>{
      'en': 'en_IN',
      'ta': 'ta_IN',
      'hi': 'hi_IN',
      'te': 'te_IN',
      'kn': 'kn_IN',
      'ml': 'ml_IN',
      'mr': 'mr_IN',
      'bn': 'bn_IN',
      'gu': 'gu_IN',
      'pa': 'pa_IN',
      'or': 'or_IN',
      'as': 'as_IN',
      'ur': 'ur_IN',
    };
    return map[language] ?? 'en_IN';
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;
    _latestText = text;
    if (!_transcript.isClosed) _transcript.add(text);
  }

  @override
  Future<bool> startRecording({String? language}) async {
    if (!await _ensureInitialized()) return false;
    if (_speech.isListening) return false;

    _latestText = '';
    _lastError = null;
    try {
      await _speech.listen(
        onResult: _onResult,
        localeId: _localeFor(language),
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        onSoundLevelChange: (level) {
          if (!_amplitude.isClosed) _amplitude.add(level);
        },
      );
      return _speech.isListening;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  @override
  Future<VoiceCaptureResult> stopAndTranscribe({String? language}) async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
      final text = _latestText.trim();
      if (text.isEmpty) {
        return VoiceCaptureResult(
          error: _lastError ?? 'Could not understand the speech. Please try again.',
          provider: 'device-speech',
        );
      }
      return VoiceCaptureResult(
        success: true,
        text: text,
        provider: 'device-speech',
      );
    } catch (e) {
      return VoiceCaptureResult(
        error: 'Voice input failed. Please try again.',
        provider: 'device-speech',
      );
    }
  }

  @override
  Future<void> cancel() async {
    _latestText = '';
    _lastError = null;
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
