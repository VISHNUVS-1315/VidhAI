import 'package:flutter/foundation.dart';
import 'package:vidhai/services/ai/voice_output_service.dart';

/// Singleton TTS service that wraps VoiceOutputService for app-wide use.
/// The app's assistant, chat screen, and live voice screen all depend on this
/// interface; it delegates to the on-device FallbackTtsVoiceOutput by default,
/// with a backend Google fallback.
class TtsService with ChangeNotifier {
  TtsService._();

  static final TtsService instance = TtsService._();

  /// The currently active backend name (e.g. 'onDeviceTts', 'backendGoogle', 'none').
  String _activeBackend = 'none';

  /// Whether TTS is currently speaking.
  bool _isSpeaking = false;

  /// Get whether TTS is currently speaking.
  bool get isSpeaking => _isSpeaking;

  /// Get the name of the currently active backend.
  String get activeBackend => _activeBackend;

  /// Priority-ordered list of backends to try when speaking.
  List<VoiceOutputBackend> get _priorityOrder => [
        FallbackTtsVoiceOutput(),
        BackendGoogleTtsVoiceOutput(),
        GeminiLiveVoiceOutput()
      ];

  /// Speak the given [text] in the optional [language].
  /// Returns whether speech was initiated successfully.
  Future<bool> speak(String text, {String? language}) async {
    for (final backend in _priorityOrder) {
      try {
        final ok = await backend.speak(text, language: language);
        if (ok) {
          _activeBackend = backend.name;
          _isSpeaking = true;
          notifyListeners();
          return true;
        }
        await backend.stop();
      } catch (e) {
        await backend.stop();
      }
    }
    _activeBackend = 'none';
    _isSpeaking = false;
    notifyListeners();
    return false;
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    _isSpeaking = false;
    notifyListeners();
    for (final backend in _priorityOrder) {
      await backend.stop();
    }
  }
}
