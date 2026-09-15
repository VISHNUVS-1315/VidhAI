import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/services/ai/ai_config.dart';
import 'package:vidhai/services/ai/ai_service.dart';

void main() {
  test('AI configuration is backend-only', () {
    const config = AIConfig();
    expect(config.provider, AIProvider.backend);
    expect(config.isBackend, isTrue);
  });

  test('AIResponse parses structured NVIDIA content', () {
    final response = AIResponse.ok(
      '{"answer":"Use groundnut","confidence":88}',
      provider: 'nvidia',
    );
    expect(response.success, isTrue);
    expect(response.provider, 'nvidia');
    expect(response.jsonContent?['answer'], 'Use groundnut');
    expect(response.jsonContent?['confidence'], 88);
  });

  test('AIResponse strips JSON code fences', () {
    final response = AIResponse.ok(
      'NaNjson\n{"ok":true}\nNaN',
    );
    expect(response.jsonContent?['ok'], isTrue);
  });

  test('AIResponse failure exposes the real error', () {
    final response = AIResponse.fail('backend unavailable');
    expect(response.success, isFalse);
    expect(response.error, 'backend unavailable');
    expect(response.provider, 'nvidia');
  });
}
