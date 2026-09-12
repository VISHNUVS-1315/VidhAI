import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'secure_api_client.dart';

/// Abstraction over a voice-output backend. The assistant UI only talks to
/// [VoiceOutputService]; it never cares which provider produced the audio.
abstract class VoiceOutputBackend {
  /// Provider id shown in diagnostics / transcript headers (e.g. 'onDevice').
  String get name;

  /// Real TTS engines (flutter_tts / Google Cloud) always return audio bytes or
  /// speak directly; anything exotic (Gemini Live native audio) reports whether
  /// it produced playable audio through [speak].
  Future<bool> speak(String text, {String? language});

  Future<void> stop();
}

/// Gemini Live / native-audio voice output. The app does not (yet) hold an
/// active Gemini Live audio session, so this backend is intentionally not
/// connected: [speak] returns false and routing falls through to the real TTS
/// fallback. Keeping the slot here preserves the spec's provider abstraction
/// without faking audio.
class GeminiLiveVoiceOutput implements VoiceOutputBackend {
  @override
  String get name => 'geminiLive';

  @override
  Future<bool> speak(String text, {String? language}) async => false;

  @override
  Future<void> stop() async {}
}

/// A [VoiceOutputBackend] that also reports whether real audio is currently
/// playing ([speaking]) and fires [speakingChanges] on every start/stop. The
/// voice conversation engine listens to those notifications to continue its
/// loop or let the user interrupt the assistant mid-speech.
abstract class VoiceSynthesizer implements VoiceOutputBackend {
  bool get speaking;

  Stream<bool> get speakingChanges;

  /// Which backend produced (or is currently producing) audio, e.g.
  /// 'onDeviceTts', 'backendGoogle', 'geminiLive', 'none'.
  String get activeBackend;
}

/// On-device TTS (Android system TextToSpeech / Google TTS engine via
/// flutter_tts). This is the reliable primary: real audio, zero dependency on
/// the backend, offline, and the platform engines natively cover the Indian
/// languages (ta-IN, hi-IN, te-IN, kn-IN, ml-IN, bn-IN, ...).
class FallbackTtsVoiceOutput implements VoiceOutputBackend {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;

  void Function(bool speaking)? onSpeakingChanged;
  void Function(String message)? onError;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(_markDone);
    _tts.setCancelHandler(_markDone);
    _tts.setErrorHandler((message) {
      onError?.call(message);
      _markDone();
    });
  }

  @override
  String get name => 'onDeviceTts';

  bool get speaking => _speaking;

  void _setSpeaking(bool value) {
    if (_speaking == value) return;
    _speaking = value;
    onSpeakingChanged?.call(value);
  }

  void _markDone() => _setSpeaking(false);

  @override
  Future<bool> speak(String text, {String? language}) async {
    try {
      await _ensureInit();
      final lang = VoiceOutputService.ttsLanguageCode(language ?? 'en');
      final ok = await _tts.setLanguage(lang);
      if (ok != 1) {
        final fallback = await _tts.setLanguage('en-US');
        if (fallback != 1) {
          onError?.call('No TTS engine/language for $lang');
          return false;
        }
      }
      final result = await _tts.speak(text);
      if (result != 1) {
        onError?.call('Speak failed (engine returned $result)');
        return false;
      }
      return true;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    } finally {
      // If awaiting completion is disabled somewhere or the engine never fires
      // the completion handler, make sure "speaking" is not left stuck on.
      _markDone();
    }
  }

  @override
  Future<void> stop() async {
    _markDone();
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Premium network voices through the VidhAI backend (Google Cloud TTS). Used
/// only as a rescue when on-device TTS is unavailable. The deployed Spark-plan
/// backend currently 404s /ai/tts, so this path is rarely exercised.
class BackendGoogleTtsVoiceOutput implements VoiceOutputBackend {
  final AudioPlayer _player = AudioPlayer();
  final SecureApiClient _client = SecureApiClient.instance;

  /// Fired when playback actually starts/stops so the router can track
  /// real "speaking" state even for audio that plays asynchronously.
  void Function(bool speaking)? onSpeakingChanged;

  BackendGoogleTtsVoiceOutput() {
    _player.onPlayerComplete.listen((_) => onSpeakingChanged?.call(false));
  }

  @override
  String get name => 'backendGoogle';

  @override
  Future<bool> speak(String text, {String? language}) async {
    try {
      final json = await _client.post('/ai/tts', {
        'text': text,
        if (language != null && language.isNotEmpty) 'language': language,
        'speakingRate': 1.0,
      });
      final base64Audio = json['base64Audio'] ?? json['audioBase64'];
      if (base64Audio is! String || base64Audio.isEmpty) return false;
      await _player.play(BytesSource(base64Decode(base64Audio)));
      onSpeakingChanged?.call(true);
      return true;
    } catch (e) {
      debugPrint('BackendGoogleTtsVoiceOutput failed: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    onSpeakingChanged?.call(false);
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}

/// Routes assistant replies to whichever voice backend can actually produce
/// audio, in priority order:
///   1. on-device TTS   (guaranteed audible, offline, multilingual)
///   2. backend Google  (premium network voice, only on failure of #1)
///   3. Gemini Live     (reserved slot; not connected yet)
///
/// The rest of the app keeps using TtsService — it only ever observes this
/// service's [speaking] / [activeBackend] state.
class VoiceOutputService extends ChangeNotifier implements VoiceSynthesizer {
  final StreamController<bool> _speakingEvents =
      StreamController<bool>.broadcast();

  VoiceOutputService._() {
    void onSpeakingChanged(bool speaking) {
      _isSpeaking = speaking;
      if (!_speakingEvents.isClosed) _speakingEvents.add(speaking);
      notifyListeners();
    }

    _onDevice.onSpeakingChanged = onSpeakingChanged;
    _backendGoogle.onSpeakingChanged = onSpeakingChanged;
  }

  static final VoiceOutputService instance = VoiceOutputService._();

  final GeminiLiveVoiceOutput _geminiLive = GeminiLiveVoiceOutput();
  final FallbackTtsVoiceOutput _onDevice = FallbackTtsVoiceOutput();
  final BackendGoogleTtsVoiceOutput _backendGoogle =
      BackendGoogleTtsVoiceOutput();

  bool _isSpeaking = false;
  String _activeBackend = 'none';
  String? _lastError;

  @override
  String get name => 'voiceRouter';

  @override
  bool get speaking => _isSpeaking;

  /// Fires true when playback starts and false when it stops (naturally or
  /// via [stop]). Used by the voice engine to continue the conversation loop
  /// and to enable barge-in while the assistant is speaking.
  @override
  Stream<bool> get speakingChanges => _speakingEvents.stream;

  bool get isSpeaking => _isSpeaking;

  /// Which backend produced (or is currently producing) audio.
  @override
  String get activeBackend => _activeBackend;

  String? get lastError => _lastError;

  void _recordError(String message) {
    _lastError = message;
    debugPrint('VoiceOutputService: $message');
  }

  List<VoiceOutputBackend> get _priorityOrder =>
      [_onDevice, _backendGoogle, _geminiLive];

  @override
  Future<bool> speak(String text, {String? language}) async {
    _lastError = null;
    for (final backend in _priorityOrder) {
      try {
        final ok = await backend.speak(text, language: language);
        if (ok) {
          _activeBackend = backend.name;
          notifyListeners();
          return true;
        }
        await backend.stop();
      } catch (e) {
        _recordError('${backend.name}: $e');
        await backend.stop();
      }
    }
    _activeBackend = 'none';
    notifyListeners();
    return false;
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    if (!_speakingEvents.isClosed) _speakingEvents.add(false);
    notifyListeners();
    for (final backend in _priorityOrder) {
      await backend.stop();
    }
  }

  @override
  void dispose() {
    _speakingEvents.close();
    super.dispose();
  }

  /// Maps the app's short language code to a BCP-47 TTS tag (xx-IN) so the
  /// platform engines pick the right Indian voice.
  static String ttsLanguageCode(String languageCode) {
    const map = {
      'en': 'en-IN',
      'ta': 'ta-IN',
      'te': 'te-IN',
      'kn': 'kn-IN',
      'ml': 'ml-IN',
      'hi': 'hi-IN',
      'bn': 'bn-IN',
      'mr': 'mr-IN',
      'gu': 'gu-IN',
      'pa': 'pa-IN',
      'or': 'or-IN',
      'as': 'as-IN',
      'ur': 'ur-IN',
    };
    return map[languageCode] ?? 'en-IN';
  }
}
