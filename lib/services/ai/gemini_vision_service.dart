import 'dart:convert';

import '../../../core/config/app_config.dart';
import 'secure_api_client.dart';

class VisionAnalysis {
  final String text;
  final bool success;
  final String? error;

  const VisionAnalysis({this.success = false, this.text = '', this.error});
}

/// Sends crop/leaf images to the secure backend vision endpoint (defaults to
/// NVIDIA Nano Omni, falling back to Gemini on error). Images never touch the
/// client's own AI keys.
class GeminiVisionService {
  GeminiVisionService._();
  static final GeminiVisionService instance = GeminiVisionService._();

  final SecureApiClient _client = SecureApiClient.instance;

  Future<VisionAnalysis> analyze({
    required List<Uint8ListLike> images,
    required String prompt,
    String? language,
    String? provider,
    String? model,
  }) async {
    if (images.isEmpty) {
      return const VisionAnalysis(error: 'No image provided.');
    }
    try {
      final json = await _client.post('/ai/image', {
        'prompt': prompt,
        if (language != null && language.isNotEmpty) 'language': language,
        if (provider != null) 'provider': provider,
        'images': images
            .map((img) =>
                {'base64': base64Encode(img.bytes), 'mimeType': img.mimeType})
            .toList(),
        'model': model ?? AppConfig.geminiModel,
      });
      if (json['success'] != true) {
        return VisionAnalysis(
          error: (json['error'] as String?) ?? 'Image analysis failed.',
        );
      }
      return VisionAnalysis(
        success: true,
        text: (json['text'] ?? json['description'] ?? '').toString(),
      );
    } catch (e) {
      return VisionAnalysis(
        error: e is SecureApiException
            ? e.message
            : 'Image analysis failed. Please try again.',
      );
    }
  }
}

/// Minimal image-carrier type to avoid coupling vision to a single codec.
class Uint8ListLike {
  final List<int> bytes;
  final String mimeType;

  const Uint8ListLike({required this.bytes, this.mimeType = 'image/jpeg'});
}
