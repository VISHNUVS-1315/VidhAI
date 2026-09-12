import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/connectivity/connectivity_service.dart';
import 'deepgram_events.dart';
import 'secure_api_client.dart';

/// High-level state of the AI Live realtime transcription session.
enum AiLiveState {
  idle,
  connecting,
  listening,
  processing,
  reconnecting,
  offline,
  error,
}

/// Categorised failure reasons shown by the UI.
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

/// Credentials/config for one Deepgram realtime session, minted by the backend.
class DeepgramSession {
  const DeepgramSession({
    required this.accessToken,
    required this.wsUrl,
    required this.model,
    required this.language,
    required this.expiresIn,
  });

  final String accessToken;
  final String wsUrl;
  final String model;
  final String language;
  final int expiresIn;
}

/// Outcome returned by [RealtimeTranscriptionService.start].
enum AiLiveOutcome { started, alreadyRunning, failed }

/// Real-time streaming speech-to-text through Deepgram's `/v1/listen`
/// WebSocket (realtime transcription).
///
/// The mic's 16 kHz PCM16 stream is chunked and pushed as raw binary audio
/// frames over a WebSocket authenticated with the short-lived Bearer JWT minted
/// by the VidhAI backend (`/ai/deepgram/session`). The permanent Deepgram API
/// key never touches the device. Deepgram's endpointing + interim results drive
/// live partials and per-utterance finals, reconciled in
/// [DeepgramTranscriptAssembler].
class RealtimeTranscriptionService extends ChangeNotifier {
  RealtimeTranscriptionService({SecureApiClient? apiClient})
      : _api = apiClient ?? SecureApiClient.instance;

  static const String _defaultModel = 'nova-3';
  static const int _sampleRate = 16000;
  static const int _maxReconnectAttempts = 2;
  static const Duration _flushInterval = Duration(milliseconds: 120);
  static const Duration _sessionFetchTimeout = Duration(seconds: 20);
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _stopFinalizeGrace = Duration(milliseconds: 700);
  static const Duration _transcriptNotifyThrottle = Duration(milliseconds: 80);

  final SecureApiClient _api;
  final AudioRecorder _recorder = AudioRecorder();
  final DeepgramTranscriptAssembler _assembler = DeepgramTranscriptAssembler();

  AiLiveState _state = AiLiveState.idle;
  AiLiveErrorKind _errorKind = AiLiveErrorKind.none;
  String _errorDetail = '';

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _flushTimer;
  Timer? _connectTimeoutTimer;
  Timer? _transcriptThrottle;
  bool _transcriptNotifyQueued = false;
  final BytesBuilder _audioBuffer = BytesBuilder();

  bool _running = false;
  bool _userStopped = false;
  bool _micActive = false;
  int _reconnectAttempts = 0;
  String _languageCode = 'en';

  // ----- public state -----

  AiLiveState get state => _state;
  AiLiveErrorKind get errorKind => _errorKind;
  String get errorDetail => _errorDetail;
  String get model => _defaultModel;

  /// Live combined transcript (finalised + current interim segment).
  String get liveTranscript => _assembler.combined;

  /// Only the committed utterances.
  String get completedTranscript => _assembler.completedText;

  bool get isRunning => _running;
  bool get hasTranscript => liveTranscript.trim().isNotEmpty;
  bool get isMicActive => _micActive;

  /// Whether Deepgram currently has a streaming model for the VidhAI language.
  static bool isLanguageSupported(String? languageCode) =>
      isDeepgramLanguageSupported(languageCode);

  // ----- control -----

  /// Starts a realtime session. Returns [AiLiveOutcome.started] once the mic
  /// is streaming, or a failure outcome without throwing.
  Future<AiLiveOutcome> start({required String languageCode}) async {
    if (_state == AiLiveState.connecting ||
        _state == AiLiveState.listening ||
        _state == AiLiveState.processing ||
        _state == AiLiveState.reconnecting) {
      return AiLiveOutcome.alreadyRunning;
    }

    _resetForStart();
    _languageCode = languageCode;

    if (!isLanguageSupported(languageCode)) {
      _fail(AiLiveErrorKind.languageUnsupported);
      return AiLiveOutcome.failed;
    }

    final online = await ConnectivityService.hasInternetConnection();
    if (!online) {
      _fail(AiLiveErrorKind.noInternet);
      return AiLiveOutcome.failed;
    }

    bool micPermissioned = false;
    try {
      micPermissioned = await _recorder.hasPermission();
    } catch (_) {
      micPermissioned = false;
    }
    if (!micPermissioned) {
      _fail(AiLiveErrorKind.micPermissionDenied);
      return AiLiveOutcome.failed;
    }

    _setState(AiLiveState.connecting);
    _connectivitySub ??= ConnectivityService.onConnectivityChanged()
        .listen(_onConnectivityChanged);

    final connected = await _openSessionAndStream();
    return connected ? AiLiveOutcome.started : AiLiveOutcome.failed;
  }

  /// Flushes the in-flight audio, asks Deepgram to finalise, and cleanly tears
  /// down the session so the last utterance still yields a final transcript.
  Future<void> stop() async {
    if (!_running) return;
    _userStopped = true;
    _flushAudio();
    _sendJson(const {'type': 'Finalize'});
    await Future<void>.delayed(_stopFinalizeGrace);
    _sendJson(const {'type': 'CloseStream'});
    _running = false;
    _assembler.commitPending();
    if (hasListeners) notifyListeners();
    await _stopMic();
    _teardownWs();
    _setState(AiLiveState.idle);
  }

  /// Ends the session and discards all accumulated text.
  Future<void> cancel() async {
    _userStopped = true;
    _running = false;
    _transcriptThrottle?.cancel();
    _transcriptThrottle = null;
    _transcriptNotifyQueued = false;
    await _stopMic();
    _teardownWs();
    _assembler.clear();
    _setState(AiLiveState.idle);
  }

  /// Resets error/session bookkeeping so [start] can be called again.
  void clearError() {
    if (_state != AiLiveState.error) return;
    _errorKind = AiLiveErrorKind.none;
    _errorDetail = '';
    _setState(AiLiveState.idle);
  }

  // ----- internals: session -----

  Future<bool> _openSessionAndStream() async {
    try {
      final session = await _fetchSession();

      final ws = IOWebSocketChannel.connect(
        Uri.parse(session.wsUrl),
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      _channel = ws;
      _wsSub?.cancel();
      _wsSub = ws.stream.listen(
        _onServerEvent,
        onDone: _onWsDone,
        onError: _onWsError,
        cancelOnError: false,
      );

      try {
        await ws.ready.timeout(_connectTimeout);
      } on TimeoutException {
        _connectTimeoutTimer = null;
        _fail(AiLiveErrorKind.timedOut);
        _teardownWs();
        return false;
      }
      if (!_running || _userStopped) {
        _teardownWs();
        return false;
      }
      _connectTimeoutTimer?.cancel();
      _connectTimeoutTimer = null;
      _setState(AiLiveState.listening);
      await _startMicStream();
      return true;
    } on SecureApiException catch (e) {
      _mapSecureError(e);
      return false;
    } on TimeoutException {
      _fail(AiLiveErrorKind.timedOut);
      return false;
    } catch (_) {
      _fail(AiLiveErrorKind.connectionFailed);
      return false;
    }
  }

  Future<DeepgramSession> _fetchSession() async {
    final resp = await _api.post('/ai/deepgram/session', {
      'language': realtimeIsoCode(_languageCode),
    }).timeout(_sessionFetchTimeout);
    final token = resp['accessToken'] as String?;
    final wsUrl = resp['wsUrl'] as String?;
    if (token == null || token.isEmpty || wsUrl == null || wsUrl.isEmpty) {
      throw const SecureApiException(
        'Session returned no Deepgram credentials.',
        statusCode: 500,
      );
    }
    return DeepgramSession(
      accessToken: token,
      wsUrl: wsUrl,
      model: resp['model'] as String? ?? _defaultModel,
      language: resp['language'] as String? ?? 'en',
      expiresIn: (resp['expiresIn'] as num?)?.toInt() ?? 0,
    );
  }

  void _mapSecureError(SecureApiException e) {
    final code = e.statusCode;
    if (code == 400 && e.message.contains('LANGUAGE_UNSUPPORTED')) {
      _fail(AiLiveErrorKind.languageUnsupported, detail: e.message);
    } else if (code == 401 || code == 403) {
      _fail(AiLiveErrorKind.authFailed, detail: e.message);
    } else if (code == 429) {
      _fail(AiLiveErrorKind.rateLimited, detail: e.message);
    } else if (code != null && code >= 500) {
      _fail(AiLiveErrorKind.sessionCreationFailed, detail: e.message);
    } else {
      _fail(AiLiveErrorKind.backendUnavailable, detail: e.message);
    }
  }

  // ----- internals: socket events -----

  void _onServerEvent(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      if (_running && !_userStopped) {
        _fail(AiLiveErrorKind.malformedEvents);
      }
      return;
    }
    if (json == null) return;

    final event = parseDeepgramEvent(json);
    switch (event.type) {
      case DeepgramEventType.results:
        if (_running) {
          _assembler.addResults(
            transcript: event.transcript,
            isFinal: event.isFinal,
            speechFinal: event.speechFinal,
          );
          _notifyTranscript();
        }
        break;
      case DeepgramEventType.speechStarted:
      case DeepgramEventType.utteranceEnd:
        if (_running) {
          _assembler.commitPending();
          _notifyTranscript();
        }
        break;
      case DeepgramEventType.error:
        _handleDeepgramError(event.errorCode, event.errorMessage);
        break;
      case DeepgramEventType.metadata:
      case DeepgramEventType.unknown:
        break;
    }
  }

  void _handleDeepgramError(String? code, String? message) {
    if (!_running || _userStopped) return;
    final c = (code ?? '').toUpperCase();
    final detail = message ?? code ?? '';
    if (c.contains('AUTH') ||
        c.contains('INVALID_API_KEY') ||
        c.contains('FORBIDDEN') ||
        c.contains('TOKEN')) {
      _fail(AiLiveErrorKind.authFailed, detail: detail);
    } else if (c.contains('RATE') ||
        c.contains('429') ||
        c.contains('NOT_ALLOWED')) {
      _fail(AiLiveErrorKind.rateLimited, detail: detail);
    } else {
      _fail(AiLiveErrorKind.unknown, detail: detail);
    }
  }

  void _onWsDone() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
    if (!_running || _userStopped || _state == AiLiveState.offline) return;
    unawaited(_attemptReconnect());
  }

  void _onWsError(Object error) {
    if (!_running || _userStopped || _state == AiLiveState.offline) return;
    unawaited(_attemptReconnect());
  }

  Future<void> _attemptReconnect() async {
    if (!_running || _userStopped) return;
    _teardownWs();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _fail(AiLiveErrorKind.connectionFailed);
      return;
    }
    _reconnectAttempts++;
    _setState(AiLiveState.reconnecting);
    await _openSessionAndStream();
  }

  // ----- internals: microphone -----

  Future<void> _startMicStream() async {
    if (!_running || _userStopped || _micActive) return;
    _micActive = true;
    _audioBuffer.clear();
    try {
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      _micSub = stream.listen(
        (data) {
          if (_running && _micActive && _state != AiLiveState.offline) {
            _audioBuffer.add(data);
          }
        },
        onError: (Object _) => _onMicStreamClosed(),
        onDone: () => _onMicStreamClosed(),
        cancelOnError: false,
      );
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(_flushInterval, (_) => _flushAudio());
    } catch (_) {
      _micActive = false;
      if (_running && !_userStopped) {
        _fail(AiLiveErrorKind.micUnavailable);
      }
    }
  }

  void _onMicStreamClosed() {
    if (!_running || _userStopped || !_micActive) return;
    _micActive = false;
    _fail(AiLiveErrorKind.micUnavailable);
  }

  void _flushAudio() {
    if (!_running || _micActive == false) return;
    final bytes = _audioBuffer.takeBytes();
    if (bytes.isEmpty) return;
    _sendAudio(bytes);
  }

  Future<void> _stopMic() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _micSub?.cancel();
    _micSub = null;
    if (!_micActive) return;
    _micActive = false;
    try {
      await _recorder.stop();
    } catch (_) {
      // Mic release failures are non-fatal; the session is already done.
    }
  }

  // ----- internals: connectivity -----

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (!online) {
      if (_running &&
          !_userStopped &&
          (_state == AiLiveState.listening ||
              _state == AiLiveState.processing ||
              _state == AiLiveState.reconnecting ||
              _state == AiLiveState.connecting)) {
        await _stopMic();
        _teardownWs();
        _setState(AiLiveState.offline);
      }
      return;
    }
    if (_state == AiLiveState.offline && _running && !_userStopped) {
      final confirmed = await ConnectivityService.hasInternetConnection();
      if (!confirmed) return;
      _setState(AiLiveState.reconnecting);
      _reconnectAttempts = 0;
      final ok = await _openSessionAndStream();
      if (!ok && _running && !_userStopped) {
        _fail(AiLiveErrorKind.connectionFailed);
      }
    }
  }

  // ----- internals: teardown/state -----

  void _teardownWs() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
    final sub = _wsSub;
    _wsSub = null;
    final ch = _channel;
    _channel = null;
    sub?.cancel();
    try {
      ch?.sink.close();
    } catch (_) {}
  }

  void _resetForStart() {
    _running = true;
    _userStopped = false;
    _reconnectAttempts = 0;
    _assembler.clear();
    _errorKind = AiLiveErrorKind.none;
    _errorDetail = '';
    _teardownWs();
  }

  void _fail(AiLiveErrorKind kind, {String? detail}) {
    if (_running && !_userStopped) {
      _running = false;
      _userStopped = true;
    }
    _errorKind = kind;
    _errorDetail = detail ?? '';
    unawaited(_stopMic());
    _teardownWs();
    _setState(AiLiveState.error);
  }

  void _setState(AiLiveState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  void _notifyTranscript() {
    if (_transcriptNotifyQueued) return;
    _transcriptNotifyQueued = true;
    _transcriptThrottle?.cancel();
    _transcriptThrottle = Timer(_transcriptNotifyThrottle, () {
      _transcriptNotifyQueued = false;
      _transcriptThrottle = null;
      if (hasListeners) notifyListeners();
    });
  }

  void _sendJson(Map<String, dynamic> json) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(json));
    } catch (_) {}
  }

  void _sendAudio(List<int> bytes) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(bytes);
    } catch (_) {}
  }

  @override
  void dispose() {
    _userStopped = true;
    _running = false;
    _transcriptThrottle?.cancel();
    _transcriptThrottle = null;
    _transcriptNotifyQueued = false;
    _connectivitySub?.cancel();
    _teardownWs();
    _recorder.dispose();
    super.dispose();
  }
}
