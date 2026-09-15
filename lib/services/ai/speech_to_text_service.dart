/// Speech-to-text contract shared by all STT providers.
///
/// Implementations translate spoken audio bytes into text. The app routes
/// through this abstraction so the provider can change (Deepgram Nova-3,
/// Whisper via Groq/NVIDIA, future on-device) without touching callers.
library;

class SpeechToTextResult {
  final bool success;
  final String? text;
  final String? error;

  /// The engine that actually produced the transcript, when known
  /// (e.g. 'nova-3', 'whisper-large-v3-turbo').
  final String? provider;

  /// Wire model id reported by the engine, when available.
  final String? model;

  const SpeechToTextResult({
    this.success = false,
    this.text,
    this.error,
    this.provider,
    this.model,
  });
}

abstract class SpeechToTextService {
  /// Short stable id of this provider (e.g. 'nvidia-whisper').
  String get engineId;

  Future<SpeechToTextResult> transcribe(
    List<int> audioBytes, {
    String? language,
    String? mime,
    String? filename,
  });
}