import 'dart:async';

import '../../services/ai/device_speech_service.dart';

/// Accumulates one continuous voice turn while exposing the platform's partial
/// recognition immediately. The farmer therefore sees the transcript grow as
/// they speak instead of waiting for the silence boundary at the end of each
/// clip.
class VoiceTurnRecorder {
  VoiceTurnRecorder({DeviceSpeechService? speech})
      : _speech = speech ?? DeviceSpeechService.instance;

  final DeviceSpeechService _speech;

  static const Duration _silenceAutoEnd = Duration(milliseconds: 900);
  static const Duration _minHold = Duration(milliseconds: 350);
  static const Duration _maxClip = Duration(seconds: 20);
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

  /// Live combined transcript: finalized previous clips + the current partial.
  String get text {
    final pieces = <String>[..._parts];
    final partial = _partial.trim();
    if (partial.isNotEmpty && (pieces.isEmpty || pieces.last != partial)) {
      pieces.add(partial);
    }
    return pieces.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool get isListening => _listening;

  /// dBFS / platform sound-level feed used by the reactive AI animation.
  Stream<double> get amplitude => _speech.onAmplitude;

  /// Recognition confidence when the device recognizer provides it.
  Stream<double> get confidence => _speech.onConfidence;

  /// Fired for every meaningful partial-result change, not just final clips.
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
    _transcriptSub = _speech.onTranscript.listen(_onPartialTranscript);
    onText?.call('');
    onListening?.call(true);
    final ok = await _startSegment();
    if (!ok) {
      _listening = false;
      await _transcriptSub?.cancel();
      _transcriptSub = null;
      onListening?.call(false);
    }
    return ok;
  }

  void _onPartialTranscript(String value) {
    if (_done || !_listening) return;
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty || clean == _partial) return;
    _partial = clean;
    onText?.call(text);
  }

  Future<bool> _startSegment() async {
    if (_done || !_listening) return false;
    if (await _speech.isRecording) return false;
    _partial = '';
    bool started = false;
    if (await _speech.hasPermission()) {
      started = await _speech.startRecording(language: _language);
    }
    if (!started) return false;
    _clipStarted = DateTime.now();
    _lastSpeechAt = null;
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

  void _appendFinal(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return;
    if (_parts.isEmpty || _parts.last != clean) {
      _parts.add(clean);
    }
    _partial = '';
  }

  Future<void> _finishSegment() async {
    if (_done || _clipFinalized) return;
    _clipFinalized = true;
    _watchdog?.cancel();
    _watchdog = null;
    final result = await _speech.stopAndTranscribe(language: _language);
    if (_done) return;
    if (result.success && (result.text ?? '').trim().isNotEmpty) {
      _appendFinal(result.text!);
      onText?.call(text);
    } else if (_partial.trim().isNotEmpty) {
      // Keep the best visible partial instead of throwing away useful speech
      // when the platform fails to mark the final recognition explicitly.
      _appendFinal(_partial);
      onText?.call(text);
    }
    if (_done || !_listening) return;
    await _startSegment();
  }

  /// Stops listening, finalizes any leftover audio and returns one combined
  /// user turn. Safe to call while a segment is already being finalized.
  Future<String> finish() async {
    _done = true;
    _watchdog?.cancel();
    _watchdog = null;
    final inFlightAmp = _ampSub;
    _ampSub = null;
    final result = await _speech.stopAndTranscribe(language: _language);
    await inFlightAmp?.cancel();
    await _transcriptSub?.cancel();
    _transcriptSub = null;

    if (result.success && (result.text ?? '').trim().isNotEmpty) {
      _appendFinal(result.text!);
    } else if (_partial.trim().isNotEmpty) {
      _appendFinal(_partial);
    }

    _listening = false;
    onText?.call(text);
    onListening?.call(false);
    return text;
  }

  /// Stops everything and discards the current turn.
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
