import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'voice_preferences_service.dart';

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

    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() => _setSpeaking(false));
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((message) {
      onError?.call(message);
      _setSpeaking(false);
    });

    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(false);
    _initialized = true;
  }

  void _setSpeaking(bool value) {
    if (_speaking == value) return;
    _speaking = value;
    onSpeakingChanged?.call(value);
  }

  int _voiceQualityScore(Map<String, dynamic> voice) {
    final name = (voice['name'] ?? '').toString().toLowerCase();
    var score = 0;
    if (name.contains('natural')) score += 100;
    if (name.contains('neural')) score += 95;
    if (name.contains('enhanced')) score += 90;
    if (name.contains('premium')) score += 85;
    if (name.contains('network')) score += 70;
    if (name.contains('google')) score += 20;
    return score;
  }

  Future<bool> _configureVoice(String languageCode) async {
    final prefs = AiVoicePreferences.instance;
    await prefs.ensureLoaded();
    final profile = prefs.selected;

    await _tts.setSpeechRate(profile.speechRate);
    await _tts.setPitch(profile.pitch);

    final primary = VoiceOutputService.ttsLanguageCode(languageCode);
    final normalizedPrimary = primary.toLowerCase().replaceAll('_', '-');
    final base = normalizedPrimary.split('-').first;

    try {
      final rawVoices = await _tts.getVoices;
      final voices = <Map<String, dynamic>>[];
      if (rawVoices is List) {
        for (final item in rawVoices) {
          if (item is Map) {
            voices.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final matching = voices.where((voice) {
        final locale =
            (voice['locale'] ?? '').toString().toLowerCase().replaceAll('_', '-');
        return locale == normalizedPrimary || locale.startsWith('$base-');
      }).toList()
        ..sort((a, b) {
          final quality =
              _voiceQualityScore(b).compareTo(_voiceQualityScore(a));
          if (quality != 0) return quality;
          return (a['name'] ?? '')
              .toString()
              .compareTo((b['name'] ?? '').toString());
        });

      if (matching.isNotEmpty) {
        final chosen = matching[profile.voiceSlot % matching.length];
        final name = chosen['name']?.toString();
        final locale = chosen['locale']?.toString();
        if (name != null &&
            name.isNotEmpty &&
            locale != null &&
            locale.isNotEmpty) {
          final result = await _tts.setVoice({'name': name, 'locale': locale});
          if (result == 1) return true;
        }
      }
    } catch (_) {
      // Voice enumeration differs between platform TTS engines; language
      // selection below is the safe fallback.
    }

    final candidates = <String>[
      primary,
      base,
      if (primary != 'en-IN') 'en-IN',
      'en-US',
    ];

    final tried = <String>{};
    for (final candidate in candidates) {
      if (!tried.add(candidate)) continue;
      try {
        final result = await _tts.setLanguage(candidate);
        if (result == 1) return true;
      } catch (_) {}
    }
    return false;
  }

  @override
  Future<bool> speak(String text, {String? language}) async {
    final clean = text.trim();
    if (clean.isEmpty) return false;

    try {
      await _ensureInit();

      // Do not let two replies overlap. stop() also resets the speaking state
      // if the previous platform completion callback was missed.
      try {
        await _tts.stop();
      } catch (_) {}
      _setSpeaking(false);

      final languageSet = await _configureVoice(language ?? 'en');
      if (!languageSet) {
        onError?.call('No on-device TTS voice is available.');
        return false;
      }

      // Mark speaking before invoking the platform method. Some Android TTS
      // engines fire their start callback after speak() already returned; this
      // keeps chat/assistant state consistent during that small race window.
      _setSpeaking(true);
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
  String get activeBackend => _device.name;

  String? get lastError => _lastError;

  @override
  Future<bool> speak(String text, {String? language}) {
    _lastError = null;
    return _device.speak(text, language: language);
  }

  /// Kept as the app-wide facade signature. [engine] is intentionally ignored
  /// because VidhAI now has a single device TTS backend.
  Future<bool> speakWithEngine(
    String text, {
    String? language,
    String? engine,
  }) {
    _lastError = null;
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
