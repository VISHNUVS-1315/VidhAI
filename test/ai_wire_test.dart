import 'package:flutter_test/flutter_test.dart';
import 'package:vidhai/services/ai/nvidia_service.dart';
import 'package:vidhai/tools/ai_tool.dart';

class _TestTool extends VidhAITool {
  @override
  String get name => 'GET_WEATHER';

  @override
  String get description => 'Get current weather';

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'district': {'type': 'string'}
        }
      };

  @override
  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> arguments, {
    navigatorKey,
  }) async =>
      {'ok': true};
}

void main() {
  test('NVIDIA chat result exposes tool calls', () {
    const empty = NvidiaChatResult(content: 'hi');
    expect(empty.wantsToolCalls, isFalse);

    const withTool = NvidiaChatResult(
      success: true,
      toolCalls: [
        NvidiaToolCall(id: 'a', functionName: 'GET_WEATHER'),
      ],
    );
    expect(withTool.wantsToolCalls, isTrue);
    expect(withTool.toolCalls.single.functionName, 'GET_WEATHER');
  });

  test('tool spec uses NVIDIA-compatible function calling shape', () {
    final spec = _TestTool().toFunctionSpec();
    expect(spec['type'], 'function');
    final fn = spec['function'] as Map<String, dynamic>;
    expect(fn['name'], 'GET_WEATHER');
    expect(fn['description'], 'Get current weather');
  });
}
