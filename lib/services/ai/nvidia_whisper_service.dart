import 'speech_to_text_service.dart';
import 'secure_api_client.dart';

/// NVIDIA Whisper STT abstraction (spec tier `stt`).
///
/// NVIDIA's hosted catalogue for these keys does not expose a Whisper
/// transcription endpoint yet, so the backend resolves an `nvidia` request to
/// the best configured engine — Whisper Large V3 Turbo via Groq when available,
/// otherwise Deepgram Nova-3 — and honestly reports which engine was used in
/// [SpeechToTextResult.provider]. The app never holds any STT key.
class NvidiaWhisperService implements SpeechToTextService {
  final SecureApiClient _client;

  NvidiaWhisperService({SecureApiClient? client})
      : _client = client ?? SecureApiClient.instance;

  @override
  String get engineId => 'nvidia-whisper';

  @override
  Future<SpeechToTextResult> transcribe(
    List<int> audioBytes, {
    String? language,
    String? mime,
    String? filename,
  }) async {
    try {
      final json = await _client.postFile(
        '/ai/stt',
        field: 'audio',
        filename: filename ?? 'recording.wav',
        contentType: mime ?? 'audio/wav',
        bytes: audioBytes,
        fields: {
          if (language != null && language.isNotEmpty) 'language': language,
          'provider': 'nvidia',
        },
      );
      final text = json['text'];
      if (text is String && text.trim().isNotEmpty) {
        return SpeechToTextResult(
          success: true,
          text: text.trim(),
          provider: (json['engine'] as String?) ?? 'backend',
          model: (json['provider'] as String?) ?? 'whisper-large-v3-turbo',
        );
      }
      return const SpeechToTextResult(
        error: 'Could not understand the audio. Please try again.',
      );
    } catch (e) {
      return SpeechToTextResult(
        error: e is SecureApiException
            ? e.message
            : 'Voice input failed. Please try again.',
      );
    }
  }
}