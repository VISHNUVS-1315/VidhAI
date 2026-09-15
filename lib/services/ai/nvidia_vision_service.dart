import 'dart:convert';

import 'secure_api_client.dart';

class VisionAnalysis {
  final String text;
  final bool success;
  final String? error;

  const VisionAnalysis({
    this.success = false,
    this.text = '',
    this.error,
  });
}

/// NVIDIA vision analysis through the secure VidhAI backend.
class NvidiaVisionService {
  NvidiaVisionService._();
  static final NvidiaVisionService instance = NvidiaVisionService._();

  final SecureApiClient _client = SecureApiClient.instance;

  Future<VisionAnalysis> analyze({
    required List<Uint8ListLike> images,
    required String prompt,
    String? language,
  }) async {
    if (images.isEmpty) {
      return const VisionAnalysis(error: 'No image provided.');
    }

    try {
      final json = await _client.post('/ai/image', {
        'prompt': prompt,
        if (language != null && language.isNotEmpty) 'language': language,
        'images': images
            .map(
              (image) => {
                'base64': base64Encode(image.bytes),
                'mimeType': image.mimeType,
              },
            )
            .toList(),
      });

      if (json['success'] != true) {
        return VisionAnalysis(
          error: json['error']?.toString() ?? 'Image analysis failed.',
        );
      }

      return VisionAnalysis(
        success: true,
        text: (json['text'] ?? json['content'] ?? '').toString(),
      );
    } on SecureApiException catch (e) {
      return VisionAnalysis(error: e.message);
    } catch (_) {
      return const VisionAnalysis(
        error: 'Image analysis failed. Please try again.',
      );
    }
  }
}

class Uint8ListLike {
  final List<int> bytes;
  final String mimeType;

  const Uint8ListLike({
    required this.bytes,
    this.mimeType = 'image/jpeg',
  });
}
