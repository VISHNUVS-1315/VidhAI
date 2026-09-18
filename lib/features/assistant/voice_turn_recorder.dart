import 'dart:async';

import '../../services/ai/device_speech_service.dart';

/// Accumulates one continuous voice turn: it records audio in short clips and
/// transcribes each clip once a speech segment ends, so the farmer sees a live
/// growing transcript while still talking. It NEVER submits anything to the AI
/// on its own — the caller finalises the turn explicitly ([finish]), which is
/// what makes the "user presses ✓ to send one combined query" flow reliable.
class VoiceTurnRecorder {
  VoiceTurnRecorder({DeviceSpeechService? speech})
      : _speech = speech ?? DeviceSpeechService.instance;

  final DeviceSpeechService _speech;

  static const Duration _silenceAutoEnd = Duration(milliseconds: 1300);
  static const Duration _minHold = Duration(milliseconds: 500);
  static const Duration _maxClip = Duration(seconds: 12);
  static const double _speechDb = -30;

  final List<String> _parts = [];
  String _partial = '';
  String _language = 'en';
  bool _listening = false;
  bool _done = false;
  bool _clipFinalized = false;
  DateTime _clipStarted = DateTime.now();
  DateTime? _lastSpeechAt;
  Timer? _watchdog;
  StreamSubscription<double>? _ampSub;
  StreamSubscription<String>? _transcriptSub;

  /// Live combined transcript (updates as each segment is recognised).
  String get text => [
        ..._parts,
        if (_partial.trim().isNotEmpty) _partial.trim(),
      ].join(' ').trim();

  bool get isListening => _listening;

  /// dBFS amplitude feed for the wave animation while recording.
  Stream<double> get amplitude => _speech.onAmplitude;

  /// Fired whenever the live [text] changes.
  void Function(String combined)? onText;

  /// Fired when listening starts/stops (false also on error/cancel).
  void Function(bool listening)? onListening;

  Future<bool> start(String language) async {
    _language = language;
    _done = false;
    _listening = true;
    _parts.clear();
    _partial = '';
    await _transcriptSub?.cancel();
    _transcriptSub = _speech.onTranscript.listen((partial) {
      if (_done || !_listening) return;
      _partial = partial.trim();
      onText?.call(text);
    });
    onText?.call('');
    onListening?.call(true);
    final ok = await _startSegment();
    if (!ok) {
      _listening = false;
      onListening?.call(false);
    }
    return ok;
  }

  Future<bool> _startSegment() async {
    if (_done || !_listening) return false;
    if (await _speech.isRecording) return false;
    bool started = false;
    if (await _speech.hasPermission()) {
      started = await _speech.startRecording(language: _language);
    }
    if (!started) return false;
    _clipStarted = DateTime.now();
    _lastSpeechAt = null;
    _partial = '';
    _clipFinalized = false;
    await _ampSub?.cancel();
    _ampSub = _speech.onAmplitude.listen(_onTick);
    _watchdog?.cancel();
    _watchdog = Timer(_maxClip, () {
      unawaited(_finishSegment());
    });
    return true;
  }

  void _onTick(double db) {
    if (_done || _clipFinalized) return;
    final now = DateTime.now();
    if (db > _speechDb) {
      _lastSpeechAt = now;
      return;
    }
    final last = _lastSpeechAt;
    if (last == null) return;
    if (now.difference(_clipStarted) < _minHold) return;
    if (now.difference(last) >= _silenceAutoEnd) {
      unawaited(_finishSegment());
    }
  }

  Future<void> _finishSegment() async {
    if (_done || _clipFinalized) return;
    _clipFinalized = true;
    _watchdog?.cancel();
    _watchdog = null;
    final result = await _speech.stopAndTranscribe(language: _language);
    if (_done) return;
    final finalText = (result.text ?? '').trim();
    final fallbackPartial = _partial.trim();
    if (result.success && finalText.isNotEmpty) {
      _parts.add(finalText);
    } else if (fallbackPartial.isNotEmpty) {
      _parts.add(fallbackPartial);
    }
    _partial = '';
    onText?.call(text);
    if (_done || !_listening) return;
    await _startSegment();
  }

  /// Stops listening, transcribes any leftover audio and returns the single
  /// combined turn transcript. Safe to call while a segment is transcribing.
  Future<String> finish() async {
    _done = true;
    _watchdog?.cancel();
    _watchdog = null;
    final inFlight = _ampSub;
    _ampSub = null;
    final result = await _speech.stopAndTranscribe(language: _language);
    await inFlight?.cancel();
    final finalText = (result.text ?? '').trim();
    final fallbackPartial = _partial.trim();
    if (result.success && finalText.isNotEmpty) {
      _parts.add(finalText);
    } else if (fallbackPartial.isNotEmpty) {
      _parts.add(fallbackPartial);
    }
    _partial = '';
    await _transcriptSub?.cancel();
    _transcriptSub = null;
    _listening = false;
    onText?.call(text);
    onListening?.call(false);
    return text;
  }

  /// Stops everything and discards the turn. Safe to call at any time.
  Future<void> cancel() async {
    _done = true;
    _watchdog?.cancel();
    _watchdog = null;
    await _ampSub?.cancel();
    _ampSub = null;
    await _transcriptSub?.cancel();
    _transcriptSub = null;
    await _speech.cancel();
    _parts.clear();
    _partial = '';
    _listening = false;
    onText?.call('');
    onListening?.call(false);
  }
}
