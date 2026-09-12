import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/connectivity/connectivity_service.dart';
import '../data_service.dart';
import 'ai_orchestrator.dart';
import 'voice_output_service.dart';
import 'whisper_service.dart';

enum VoiceConversationPhase { idle, listening, thinking, speaking, error }

enum VoiceConversationError { offline, inputUnavailable, auth, generic }

/// One completed user→assistant exchange inside a live voice conversation.
class VoiceTurn {
  final String userText;
  final String reply;

  /// Which STT engine produced the transcript ('deepgram', 'groq-whisper',
  /// 'backend', or null when recognition failed).
  final String? sttProvider;

  /// Which TTS backend read the reply aloud ('onDeviceTts', 'backendGoogle',
  /// 'geminiLive', or 'none' when nothing could play).
  final String ttsBackend;

  const VoiceTurn({
    required this.userText,
    required this.reply,
    this.sttProvider,
    required this.ttsBackend,
  });
}

/// Asks the AI engine for one reply. Implementations should carry the app's
/// session context so follow-up turns stay coherent.
typedef VoiceAsk = Future<AiOrchestratorReply> Function({
  required String input,
  required String language,
});

/// Drives a continuous two-way voice conversation: listen (auto-ends after a
/// short silence), transcribe via [VoiceCapturer], ask the AI, speak the
/// reply via [VoiceSynthesizer] and loop until the user stops or turns off
/// auto-continue. The user can interrupt the assistant mid-speech (barge-in)
/// and simply start talking again.
///
/// Everything is injectable so the engine is fully unit-testable with fakes;
/// the production defaults use the real Whisper backend and the provider-routed
/// TTS ([VoiceOutputService]).
class VoiceConversationController extends ChangeNotifier {
  VoiceConversationController({
    VoiceCapturer? capturer,
    VoiceSynthesizer? synthesizer,
    Future<String> Function()? getLanguage,
    VoiceAsk? ask,
    Future<bool> Function()? hasInternetConnection,
    this.silenceAutoEnd = const Duration(milliseconds: 1400),
    this.minHold = const Duration(milliseconds: 500),
    this.maxClip = const Duration(seconds: 12),
    this.speechDb = -30,
    bool bargeInEnabled = true,
    this.bargeInDb = -28,
    this.bargeInHold = const Duration(milliseconds: 450),
    this.bargeInIgnoreWindow = const Duration(milliseconds: 500),
  })  : _capturer = capturer ?? WhisperService.instance,
        _synthesizer = synthesizer ?? VoiceOutputService.instance,
        _getLanguage = getLanguage ?? _defaultGetLanguage,
        _ask = ask ?? _defaultAsk,
        _hasConnection =
            hasInternetConnection ?? ConnectivityService.hasInternetConnection,
        _bargeInEnabled = bargeInEnabled;

  final VoiceCapturer _capturer;
  final VoiceSynthesizer _synthesizer;
  final Future<String> Function() _getLanguage;
  final VoiceAsk _ask;
  final Future<bool> Function() _hasConnection;

  /// Listening: a turn auto-ends after this much silence following speech.
  final Duration silenceAutoEnd;

  /// Listening: ignore audio that ends sooner than this after recording starts
  /// (guards against a random blip ending the turn instantly).
  final Duration minHold;

  /// Listening: hard cap for one recording regardless of speech.
  final Duration maxClip;

  /// Listening: amplitude (dBFS) above which we consider the user to be
  /// speaking.
  final double speechDb;

  /// Barge-in: amplitude (dBFS) sustained enough to interrupt the assistant.
  final double bargeInDb;

  /// Barge-in: how long the user must keep talking before interrupting.
  final Duration bargeInHold;

  /// Barge-in: ignore the first moments of assistant speech (the assistant's
  /// own voice on the device speaker often trips the mic).
  final Duration bargeInIgnoreWindow;

  bool _bargeInEnabled;
  bool _running = false;
  bool _autoContinue = true;
  bool _disposed = false;
  bool _bargedIn = false;

  VoiceConversationPhase _phase = VoiceConversationPhase.idle;
  VoiceConversationError? _error;
  String? _errorDetail;
  String _transcript = '';
  String _reply = '';
  final List<VoiceTurn> _turns = [];
  String? _lastSttProvider;
  String _lastTtsBackend = 'none';

  StreamSubscription<double>? _ampSub;
  Completer<void>? _listenGate;
  DateTime? _speakStartedAt;

  // ── Public state ──────────────────────────────────────────────────────────

  VoiceConversationPhase get phase => _phase;
  bool get running => _running;
  bool get autoContinue => _autoContinue;
  bool get bargeInEnabled => _bargeInEnabled;
  VoiceConversationError? get error => _error;

  /// Raw failure text from the STT provider when available (localized as a
  /// generic message but kept here for the UI to display if desired).
  String? get errorDetail => _errorDetail;

  /// Current turn: what the user said (before it is answered).
  String get transcript => _transcript;

  /// Current turn: the assistant's reply (while/after speaking).
  String get reply => _reply;

  /// Completed exchanges of this session.
  List<VoiceTurn> get turns => List.unmodifiable(_turns);

  /// Which STT engine produced the last transcript.
  String? get lastSttProvider => _lastSttProvider;

  /// Which TTS backend produced the last reply's audio.
  String get lastTtsBackend => _lastTtsBackend;

  /// Live mic amplitude feed (0..1 normalised in the UI) while recording.
  Stream<double> get amplitude => _capturer.onAmplitude;

  // ── Control ───────────────────────────────────────────────────────────────

  /// Starts (or resumes) the live conversation loop. No-op while running.
  Future<void> start() async {
    if (_running || _disposed) return;
    _running = true;
    _error = null;
    _errorDetail = null;
    _transcript = '';
    _reply = '';
    notifyListeners();
    unawaited(_runLoop());
  }

  /// Stops the mic, any recognition, any speech and the loop immediately.
  Future<void> stop() async {
    _running = false;
    _openListenGate();
    _ampSub?.cancel();
    _ampSub = null;
    await _capturer.cancel();
    await _synthesizer.stop();
    _transcript = '';
    _reply = '';
    _error = null;
    _errorDetail = null;
    _setPhase(VoiceConversationPhase.idle);
  }

  /// Clears the accumulated session turns and provider diagnostics.
  void reset() {
    _turns.clear();
    _lastSttProvider = null;
    _lastTtsBackend = 'none';
    notifyListeners();
  }

  void toggleAutoContinue() {
    _autoContinue = !_autoContinue;
    notifyListeners();
  }

  void setBargeIn(bool enabled) {
    if (_bargeInEnabled == enabled) return;
    _bargeInEnabled = enabled;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _running = false;
    _openListenGate();
    _ampSub?.cancel();
    _ampSub = null;
    super.dispose();
  }

  // ── Loop ──────────────────────────────────────────────────────────────────

  Future<void> _runLoop() async {
    while (_running) {
      final transcribed = await _listenOnce();
      if (!transcribed || !_running) break;
      final answered = await _askAndSpeak();
      if (!answered || !_running) break;
      if (!_autoContinue) break;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (_running && !_disposed) _setPhase(VoiceConversationPhase.idle);
  }

  /// Records one turn using VAD (auto-end on silence) and transcribes it.
  /// Returns true when a non-empty transcript was produced.
  Future<bool> _listenOnce() async {
    if (!_running) return false;
    await _synthesizer.stop();

    if (!await _hasConnection()) {
      _poseError(VoiceConversationError.offline);
      return false;
    }

    final language = await _getLanguage();
    if (!_running) return false;

    _transcript = '';
    _reply = '';
    _error = null;
    _errorDetail = null;
    _setPhase(VoiceConversationPhase.listening);

    if (!await _capturer.hasPermission()) {
      _poseError(VoiceConversationError.inputUnavailable);
      return false;
    }
    if (!await _capturer.startRecording()) {
      _poseError(VoiceConversationError.inputUnavailable);
      return false;
    }

    await _awaitSpeechEnd();
    if (!_running) return false;

    final result = await _capturer.stopAndTranscribe(language: language);
    if (!_running) return false;

    _lastSttProvider = result.provider;
    if (!result.success || (result.text ?? '').trim().isEmpty) {
      _errorDetail = result.error;
      _poseError(VoiceConversationError.generic);
      return false;
    }

    _transcript = result.text!.trim();
    notifyListeners();
    return true;
  }

  /// Waits for speech to start and then for a configurable silence (or the
  /// hard clip cap) to finalise the recording. Aborts via the gate when the
  /// controller is stopped.
  Future<void> _awaitSpeechEnd() async {
    final completer = Completer<void>();
    _listenGate = completer;
    final startedAt = DateTime.now();
    DateTime? lastSpeechAt;
    Timer? maxTimer;

    void maybeEnd() {
      if (completer.isCompleted) return;
      final now = DateTime.now();
      if (lastSpeechAt != null &&
          now.difference(startedAt) >= minHold &&
          now.difference(lastSpeechAt!) >= silenceAutoEnd) {
        completer.complete();
      }
    }

    _ampSub?.cancel();
    _ampSub = _capturer.onAmplitude.listen((db) {
      if (db > speechDb) {
        lastSpeechAt = DateTime.now();
      } else if (lastSpeechAt != null) {
        maybeEnd();
      }
    });

    maxTimer = Timer(maxClip, () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;

    maxTimer.cancel();
    _ampSub?.cancel();
    _ampSub = null;
    _listenGate = null;
  }

  /// Asks the AI for the current turn, records the turn, then speaks the reply
  /// while listening for barge-in. Returns true when a reply was produced.
  Future<bool> _askAndSpeak() async {
    if (!_running) return false;
    _setPhase(VoiceConversationPhase.thinking);

    final language = await _getLanguage();
    final reply = await _ask(input: _transcript, language: language);
    if (!_running) return false;

    if (reply.failed) {
      _poseError(switch (reply.error) {
        AiErrorKind.offline => VoiceConversationError.offline,
        AiErrorKind.auth => VoiceConversationError.auth,
        _ => VoiceConversationError.generic,
      });
      return false;
    }

    _reply = reply.text;
    _bargedIn = false;
    _lastTtsBackend = _synthesizer.activeBackend;
    _turns.add(VoiceTurn(
      userText: _transcript,
      reply: reply.text,
      sttProvider: _lastSttProvider,
      ttsBackend: _lastTtsBackend,
    ));
    notifyListeners();

    _setPhase(VoiceConversationPhase.speaking);
    _speakStartedAt = DateTime.now();
    final playing = await _synthesizer.speak(reply.text, language: language);
    if (!playing) _lastTtsBackend = 'none';

    await _waitForSpeechEnd(playing);
    if (!_running) return false;
    _setPhase(VoiceConversationPhase.idle);
    return true;
  }

  /// Awaits the end of the spoken reply, interrupting it (barge-in) when the
  /// user starts talking and [bargeInEnabled] is on.
  Future<void> _waitForSpeechEnd(bool playing) async {
    if (!playing || !_running) return;
    final completer = Completer<void>();
    StreamSubscription<bool>? speakSub;

    void finish() {
      speakSub?.cancel();
      if (!completer.isCompleted) completer.complete();
    }

    speakSub = _synthesizer.speakingChanges.listen((speaking) {
      if (!speaking) finish();
    });

    if (_bargeInEnabled) {
      DateTime? loudSince;
      _ampSub?.cancel();
      _ampSub = _capturer.onAmplitude.listen((db) {
        final now = DateTime.now();
        if (db > bargeInDb) {
          loudSince ??= now;
          final started = _speakStartedAt;
          if (started != null &&
              now.difference(started) >= bargeInIgnoreWindow &&
              now.difference(loudSince!) >= bargeInHold) {
            _triggerBargeIn();
          }
        } else {
          loudSince = null;
        }
      });
    }

    await completer.future;
    _ampSub?.cancel();
    _ampSub = null;
  }

  /// Interrupts the assistant: stops the audio (which emits speaking=false and
  /// therefore completes [finish]'s wait) so the loop can start listening.
  void _triggerBargeIn() {
    if (_bargedIn || _disposed) return;
    _bargedIn = true;
    _ampSub?.cancel();
    _ampSub = null;
    unawaited(_synthesizer.stop());
  }

  void _poseError(VoiceConversationError kind) {
    _running = false;
    _error = kind;
    debugPrint(
        '[VidhAI] voice conversation error kind=$kind'); // SAFE: no secrets
    _setPhase(VoiceConversationPhase.error);
  }

  void _setPhase(VoiceConversationPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  void _openListenGate() {
    final gate = _listenGate;
    _listenGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  // ── Defaults (production wiring) ──────────────────────────────────────────

  static Future<String> _defaultGetLanguage() =>
      DataService().getSelectedLanguage();

  static Future<AiOrchestratorReply> _defaultAsk({
    required String input,
    required String language,
  }) async {
    final data = DataService();
    final profile = await data.loadCachedProfile();
    final farms = await data.loadFarms();
    return AiOrchestrator.instance.process(
      input: input,
      language: language,
      userProfile: profile?.toMap() ?? {},
      farms: farms.map((f) => f.toMap()).take(5).toList(),
      contextExtras: const {'source': 'voice'},
    );
  }
}
