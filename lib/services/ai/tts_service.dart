import 'dart:async';

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
  }) async {
    final started = await _router.speakWithEngine(
      text,
      language: language,
      engine: engine,
    );
    if (!started) return false;

    // Subscribe before checking the current flag so a very fast platform
    // completion cannot be missed between the state check and the listener.
    final done = Completer<void>();
    late final StreamSubscription<bool> sub;
    sub = _router.speakingChanges.listen((speaking) {
      if (!speaking && !done.isCompleted) done.complete();
    });
    if (!_router.speaking && !done.isCompleted) done.complete();

    try {
      await done.future.timeout(const Duration(seconds: 90));
      return true;
    } on TimeoutException {
      await _router.stop();
      return false;
    } finally {
      await sub.cancel();
    }
  }

  /// Stop the exact backend that is currently speaking.
  Future<void> stop() => _router.stop();
}
