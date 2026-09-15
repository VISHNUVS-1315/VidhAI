import 'dart:async';

import 'package:flutter/foundation.dart';

import 'device_speech_service.dart';

/// High-level state of the AI Live on-device transcription session.
enum AiLiveState {
  idle,
  connecting,
  listening,
  processing,
  reconnecting,
  offline,
  error,
}

/// Categorised failure reasons shown by the existing AI Live UI.
enum AiLiveErrorKind {
  none,
  noInternet,
  micPermissionDenied,
  micUnavailable,
  backendUnavailable,
  sessionCreationFailed,
  languageUnsupported,
  connectionFailed,
  authFailed,
  rateLimited,
  timedOut,
  malformedEvents,
  unknown,
}

enum AiLiveOutcome { started, alreadyRunning, failed }

/// Realtime speech-to-text for AI Live using the phone's platform speech
/// recognizer. No external STT provider, WebSocket, or API key is required.
class RealtimeTranscriptionService extends ChangeNotifier {
  RealtimeTranscriptionService({DeviceSpeechService? speech})
      : _speech = speech ?? DeviceSpeechService.instance;

  final DeviceSpeechService _speech;
  StreamSubscription<String>? _transcriptSub;

  AiLiveState _state = AiLiveState.idle;
  AiLiveErrorKind _errorKind = AiLiveErrorKind.none;
  String _errorDetail = '';
  String _liveTranscript = '';
  String _completedTranscript = '';
  bool _running = false;
  bool _micActive = false;
  String _languageCode = 'en';

  AiLiveState get state => _state;
  AiLiveErrorKind get errorKind => _errorKind;
  String get errorDetail => _errorDetail;
  String get model => 'device-speech';
  String get liveTranscript => _liveTranscript;
  String get completedTranscript => _completedTranscript;
  bool get isRunning => _running;
  bool get hasTranscript => _liveTranscript.trim().isNotEmpty;
  bool get isMicActive => _micActive;

  static bool isLanguageSupported(String? languageCode) {
    const supported = {
      'en',
      'ta',
      'hi',
      'te',
      'kn',
      'ml',
      'mr',
      'bn',
      'gu',
      'pa',
      'or',
      'as',
      'ur',
    };
    return supported.contains((languageCode ?? 'en').toLowerCase());
  }

  Future<AiLiveOutcome> start({required String languageCode}) async {
    if (_running) return AiLiveOutcome.alreadyRunning;
    if (!isLanguageSupported(languageCode)) {
      _fail(AiLiveErrorKind.languageUnsupported);
      return AiLiveOutcome.failed;
    }

    _languageCode = languageCode;
    _errorKind = AiLiveErrorKind.none;
    _errorDetail = '';
    _liveTranscript = '';
    _completedTranscript = '';
    _setState(AiLiveState.connecting);

    if (!await _speech.hasPermission()) {
      _fail(AiLiveErrorKind.micPermissionDenied);
      return AiLiveOutcome.failed;
    }

    await _transcriptSub?.cancel();
    _transcriptSub = _speech.onTranscript.listen((text) {
      if (!_running) return;
      _liveTranscript = text.trim();
      if (_liveTranscript.isNotEmpty) {
        _completedTranscript = _liveTranscript;
      }
      notifyListeners();
    });

    final started =
        await _speech.startRecording(language: _languageCode);
    if (!started) {
      _fail(AiLiveErrorKind.micUnavailable);
      return AiLiveOutcome.failed;
    }

    _running = true;
    _micActive = true;
    _setState(AiLiveState.listening);
    return AiLiveOutcome.started;
  }

  Future<void> stop() async {
    if (!_running) {
      _setState(AiLiveState.idle);
      return;
    }
    _setState(AiLiveState.processing);
    _micActive = false;
    final result =
        await _speech.stopAndTranscribe(language: _languageCode);
    _running = false;
    if (result.success && (result.text ?? '').trim().isNotEmpty) {
      _liveTranscript = result.text!.trim();
      _completedTranscript = _liveTranscript;
    } else if (_liveTranscript.trim().isEmpty) {
      _errorDetail = result.error ?? '';
    }
    _setState(AiLiveState.idle);
  }

  Future<void> cancel() async {
    _running = false;
    _micActive = false;
    _liveTranscript = '';
    _completedTranscript = '';
    await _speech.cancel();
    await _transcriptSub?.cancel();
    _transcriptSub = null;
    _setState(AiLiveState.idle);
  }

  void clearError() {
    _errorKind = AiLiveErrorKind.none;
    _errorDetail = '';
    if (_state == AiLiveState.error) {
      _setState(AiLiveState.idle);
    } else {
      notifyListeners();
    }
  }

  void _fail(AiLiveErrorKind kind, {String detail = ''}) {
    _running = false;
    _micActive = false;
    _errorKind = kind;
    _errorDetail = detail;
    _setState(AiLiveState.error);
  }

  void _setState(AiLiveState next) {
    if (_state == next) {
      notifyListeners();
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _running = false;
    _micActive = false;
    _transcriptSub?.cancel();
    super.dispose();
  }
}
