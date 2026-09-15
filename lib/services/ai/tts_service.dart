import 'package:flutter/foundation.dart';
import 'package:vidhai/services/ai/voice_output_service.dart';

/// App-wide TTS facade backed by the single [VoiceOutputService] instance.
///
/// Keeping one router instance is important: stop/cancel must target the same
/// audio backend that started speaking, and natural completion must propagate
/// back to chat/assistant UI instead of leaving isSpeaking stuck on true.
class TtsService with ChangeNotifier {
  TtsService._() {
    _router.addListener(_syncFromRouter);
  }

  static final TtsService instance = TtsService._();

  final VoiceOutputService _router = VoiceOutputService.instance;

  bool get isSpeaking => _router.speaking;

  String get activeBackend => _router.activeBackend;

  void _syncFromRouter() {
    notifyListeners();
  }

  /// Speak through the requested engine first, then the configured fallbacks.
  Future<bool> speak(
    String text, {
    String? language,
    String? engine,
  }) {
    return _router.speakWithEngine(
      text,
      language: language,
      engine: engine,
    );
  }

  /// Stop the exact backend that is currently speaking.
  Future<void> stop() => _router.stop();
}
