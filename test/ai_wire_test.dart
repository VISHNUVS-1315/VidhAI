import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/models/ai/ai_message.dart';
import 'package:vidhai/models/ai/ai_tool_call.dart';
import 'package:vidhai/services/ai/deepgram_service.dart';
import 'package:vidhai/services/ai/gemini_service.dart';
import 'package:vidhai/services/ai/groq_service.dart';

void main() {
  group('GeminiService.toGeminiContents', () {
    test('plain user/model turns map 1:1', () {
      final contents = GeminiService.toGeminiContents([
        AIMessage.user('hello'),
        AIMessage.assistant('hi there'),
      ]);
      expect(contents, hasLength(2));
      expect(contents[0], {
        'role': 'user',
        'parts': [
          {'text': 'hello'}
        ]
      });
      expect(contents[1], {
        'role': 'model',
        'parts': [
          {'text': 'hi there'}
        ]
      });
    });

    test('tool call + tool result become functionCall + functionResponse', () {
      final contents = GeminiService.toGeminiContents([
        AIMessage.user('weather please'),
        AIMessage(
          role: 'assistant',
          content: '',
          toolCalls: const [
            AIToolCall(id: 'c1', name: 'GET_WEATHER', arguments: {}),
          ],
        ),
        AIMessage.fromToolResult('c1', '{"temp":31}'),
      ]);
      expect(contents, hasLength(3));
      expect(
        contents[1],
        {
          'role': 'model',
          'parts': [
            {
              'functionCall': {
                'name': 'GET_WEATHER',
                'args': <String, dynamic>{}
              },
            },
          ],
        },
      );
      expect(
        contents[2],
        {
          'role': 'function',
          'parts': [
            {
              'functionResponse': {
                'name': 'GET_WEATHER',
                'response': {'temp': 31},
              },
            },
          ],
        },
      );
    });
  });

  group('GeminiService.toFunctionDeclarations', () {
    test('converts Groq specs to Gemini declarations', () {
      final decls = GeminiService.toFunctionDeclarations([
        {
          'type': 'function',
          'function': {
            'name': 'GET_WEATHER',
            'description': 'Shows weather.',
            'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
          },
        },
      ]);
      expect(decls, hasLength(1));
      expect(decls.first['name'], 'GET_WEATHER');
      expect(decls.first['description'], 'Shows weather.');
      expect(decls.first['parameters'], isA<Map>());
    });
  });

  group('GeminiService.parseDirectResponse', () {
    test('text + functionCall parts become content + tool calls', () {
      final result = GeminiService.parseDirectResponse({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Let me check.'},
                {
                  'functionCall': {
                    'name': 'GET_WEATHER',
                    'args': {'district': 'Solapur'},
                  },
                },
              ],
            },
          },
        ],
      });
      expect(result.success, isTrue);
      expect(result.content, 'Let me check.');
      expect(result.wantsToolCalls, isTrue);
      expect(result.toolCalls.single.functionName, 'GET_WEATHER');
      expect(result.toolCalls.single.arguments, {'district': 'Solapur'});
    });

    test('blocked prompt surfaces as a friendly failure', () {
      final result = GeminiService.parseDirectResponse({});
      expect(result.success, isFalse);
    });
  });

  group('DeepgramService.buildListenUri', () {
    test('wire format is Nova-3 + smart_format + language', () {
      final uri = DeepgramService.buildListenUri(language: 'ta');
      expect(uri.path, '/v1/listen');
      expect(uri.queryParameters['model'], 'nova-3');
      expect(uri.queryParameters['smart_format'], 'true');
      expect(uri.queryParameters['language'], 'ta');
    });

    test('keyterms become repeated query params', () {
      final uri = DeepgramService.buildListenUri(
        language: 'en',
        keyterms: const ['crop', 'fertilizer'],
      );
      final values = uri.queryParametersAll['keyterm']!;
      expect(values, containsAll(['crop', 'fertilizer']));
    });
  });

  group('GroqToolCall wire', () {
    test('wantsToolCalls only when calls exist', () {
      expect(GroqChatResult(content: 'hi').wantsToolCalls, isFalse);
      expect(
        GroqChatResult(
          content: '',
          toolCalls: const [GroqToolCall(id: 'a', functionName: 'GET_WEATHER')],
        ).wantsToolCalls,
        isTrue,
      );
    });
  });
}
