import 'package:flutter_test/flutter_test.dart';

import 'package:vidhai/services/ai/voice_output_service.dart';

void main() {
  group('VoiceOutputService.ttsLanguageCode', () {
    test('maps every supported app language to an Indian BCP-47 tag', () {
      const cases = <String, String>{
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
      cases.forEach((code, tag) {
        expect(
          VoiceOutputService.ttsLanguageCode(code),
          tag,
          reason: '$code should map to $tag',
        );
      });
    });

    test('unknown codes fall back to en-IN', () {
      expect(VoiceOutputService.ttsLanguageCode('fr'), 'en-IN');
      expect(VoiceOutputService.ttsLanguageCode(''), 'en-IN');
    });
  });

  test('voice output is device-only', () {
    expect(VoiceOutputService.instance.name, 'deviceTts');
    expect(VoiceOutputService.instance.activeBackend, 'deviceTts');
  });
}
