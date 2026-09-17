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

/// Low-latency platform speech recognition using Android/iOS speech services.
///
/// Partial results are emitted immediately so the UI can render words while
/// the farmer is still speaking. The selected VidhAI locale is passed through
/// [SpeechListenOptions] (rather than mixing deprecated listen parameters with
/// options), which keeps multilingual recognition consistent.
class DeviceSpeechService implements VoiceCapturer {
  DeviceSpeechService._();
  static final DeviceSpeechService instance = DeviceSpeechService._();

  final SpeechToText _speech = SpeechToText();
  final StreamController<double> _amplitude =
      StreamController<double>.broadcast();
  final StreamController<String> _transcript =
      StreamController<String>.broadcast();
  final StreamController<double> _confidence =
      StreamController<double>.broadcast();

  bool _initialized = false;
  String _latestText = '';
  String _lastEmittedText = '';
  String? _lastError;
  double? _latestConfidence;

  @override
  Stream<double> get onAmplitude => _amplitude.stream;

  @override
  Stream<String> get onTranscript => _transcript.stream;

  /// Recognition confidence when the platform supplies one (0.0–1.0).
  Stream<double> get onConfidence => _confidence.stream;

  double? get latestConfidence => _latestConfidence;

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
    if (result.hasConfidenceRating) {
      final confidence = result.confidence.clamp(0.0, 1.0).toDouble();
      _latestConfidence = confidence;
      if (!_confidence.isClosed) _confidence.add(confidence);
    }

    final text = result.recognizedWords.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return;
    _latestText = text;

    // Platform recognizers can emit identical partials repeatedly. Avoid
    // rebuilding every listening UI for duplicate text while still forwarding
    // every real change immediately.
    if (text == _lastEmittedText) return;
    _lastEmittedText = text;
    if (!_transcript.isClosed) _transcript.add(text);
  }

  @override
  Future<bool> startRecording({String? language}) async {
    if (!await _ensureInitialized()) return false;
    if (_speech.isListening) return false;

    _latestText = '';
    _lastEmittedText = '';
    _latestConfidence = null;
    _lastError = null;
    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          localeId: _localeFor(language),
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(milliseconds: 900),
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          listenMode: ListenMode.dictation,
        ),
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
        // A short grace period lets the platform deliver its final result while
        // keeping perceived turn latency well below the old 180 ms delay.
        await Future<void>.delayed(const Duration(milliseconds: 70));
      }
      final text = _latestText.trim();
      if (text.isEmpty) {
        return VoiceCaptureResult(
          error: _lastError ??
              'Could not understand the speech. Please try again.',
          provider: 'device-speech',
        );
      }
      return VoiceCaptureResult(
        success: true,
        text: text,
        provider: 'device-speech',
      );
    } catch (e) {
      return const VoiceCaptureResult(
        error: 'Voice input failed. Please try again.',
        provider: 'device-speech',
      );
    }
  }

  @override
  Future<void> cancel() async {
    _latestText = '';
    _lastEmittedText = '';
    _latestConfidence = null;
    _lastError = null;
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
