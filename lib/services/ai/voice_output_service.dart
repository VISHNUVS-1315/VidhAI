import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class VoiceOutputBackend {
  String get name;
  Future<bool> speak(String text, {String? language});
  Future<void> stop();
}

abstract class VoiceSynthesizer implements VoiceOutputBackend {
  bool get speaking;
  Stream<bool> get speakingChanges;
  String get activeBackend;
}

/// On-device TTS through the platform speech engine.
///
/// VidhAI intentionally keeps voice output on the device so no separate TTS
/// provider key or network audio service is required.
class DeviceTtsVoiceOutput implements VoiceOutputBackend {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;

  void Function(bool speaking)? onSpeakingChanged;
  void Function(String message)? onError;

  @override
  String get name => 'deviceTts';

  bool get speaking => _speaking;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(false);
    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() => _setSpeaking(false));
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((message) {
      onError?.call(message);
      _setSpeaking(false);
    });
  }

  void _setSpeaking(bool value) {
    if (_speaking == value) return;
    _speaking = value;
    onSpeakingChanged?.call(value);
  }

  @override
  Future<bool> speak(String text, {String? language}) async {
    final clean = text.trim();
    if (clean.isEmpty) return false;
    try {
      await _ensureInit();
      final lang = VoiceOutputService.ttsLanguageCode(language ?? 'en');
      final languageSet = await _tts.setLanguage(lang);
      if (languageSet != 1) {
        final fallback = await _tts.setLanguage('en-IN');
        if (fallback != 1) {
          onError?.call('No on-device TTS voice for $lang');
          return false;
        }
      }
      final result = await _tts.speak(clean);
      if (result != 1) {
        onError?.call('On-device TTS could not start.');
        _setSpeaking(false);
        return false;
      }
      return true;
    } catch (e) {
      onError?.call(e.toString());
      _setSpeaking(false);
      return false;
    }
  }

  @override
  Future<void> stop() async {
    _setSpeaking(false);
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Single app-wide voice-output router. There is intentionally one backend:
/// the platform TTS engine.
class VoiceOutputService extends ChangeNotifier implements VoiceSynthesizer {
  VoiceOutputService._() {
    _device.onSpeakingChanged = (speaking) {
      _isSpeaking = speaking;
      if (!_speakingEvents.isClosed) _speakingEvents.add(speaking);
      notifyListeners();
    };
    _device.onError = (message) {
      _lastError = message;
      debugPrint('VoiceOutputService: $message');
      notifyListeners();
    };
  }

  static final VoiceOutputService instance = VoiceOutputService._();

  final DeviceTtsVoiceOutput _device = DeviceTtsVoiceOutput();
  final StreamController<bool> _speakingEvents =
      StreamController<bool>.broadcast();

  bool _isSpeaking = false;
  String? _lastError;

  @override
  String get name => 'deviceTts';

  @override
  bool get speaking => _isSpeaking;

  bool get isSpeaking => _isSpeaking;

  @override
  Stream<bool> get speakingChanges => _speakingEvents.stream;

  @override
  String get activeBackend => _isSpeaking ? _device.name : _device.name;

  String? get lastError => _lastError;

  @override
  Future<bool> speak(String text, {String? language}) {
    return _device.speak(text, language: language);
  }

  /// Kept as the app-wide facade signature. [engine] is intentionally ignored
  /// because VidhAI now has a single device TTS backend.
  Future<bool> speakWithEngine(
    String text, {
    String? language,
    String? engine,
  }) {
    return _device.speak(text, language: language);
  }

  @override
  Future<void> stop() async {
    _isSpeaking = false;
    if (!_speakingEvents.isClosed) _speakingEvents.add(false);
    notifyListeners();
    await _device.stop();
  }

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

  @override
  void dispose() {
    _speakingEvents.close();
    super.dispose();
  }
}
