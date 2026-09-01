import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/services/ai/ai_service.dart';
import 'package:vidhai/services/ai/ai_config.dart';

void main() {
  final ai = AiService.instance;

  Future<Map<String, dynamic>> ask(String q) async {
    ai.configure(const AIConfig(provider: AIProvider.mock));
    final r = await ai.chat(q);
    return jsonDecode(r.content) as Map<String, dynamic>;
  }

  test('Tomato price returns tomato price', () async {
    final p = await ask('Tomato price');
    expect(p['answer'], 'Indicative market price');
    expect((p['details'] as List).join(' '), contains('28'));
  });

  test('What should I do returns action plan', () async {
    final p = await ask('What should I do now?');
    expect(p['answer'], contains('action plan'));
  });

  test('Best crop returns recommendations', () async {
    final p = await ask('Best crop to grow?');
    expect(p['answer'], contains('Recommended crops'));
  });

  test('Cultivation of tomato returns crop guide', () async {
    final p = await ask('how to grow tomato');
    expect(p['answer'], contains('Tomato'));
  });

  test('Weather query returns weather advisory', () async {
    final p = await ask('what is the weather in sangli');
    expect(p['answer'], contains('Weather'));
  });

  test('Price word does not confuse rice lookup', () async {
    final p = await ask('Tomato price');
    expect((p['details'] as List).join(' '), contains('28'));
    final r = await ask('rice price');
    expect((r['details'] as List).join(' '), contains('2,180'));
  });
}
