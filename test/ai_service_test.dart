import 'package:flutter_test/flutter_test.dart';
import 'package:private_agent/services/ai_service.dart';

void main() {
  test('recognizes only the NVIDIA hosted API URL', () {
    expect(
      AiService.isNvidiaBaseUrl('https://integrate.api.nvidia.com/v1'),
      isTrue,
    );
    expect(AiService.isNvidiaBaseUrl('https://api.deepseek.com'), isFalse);
  });

  test('NVIDIA model picker keeps only verified free chat models', () {
    final models = AiService.filterNvidiaFreeModels([
      'paid/partner-model',
      'nvidia/nemotron-3-super-120b-a12b',
      'nvidia/embed-qa-4',
      'openai/gpt-oss-20b',
    ]);

    expect(models, ['nvidia/nemotron-3-super-120b-a12b', 'openai/gpt-oss-20b']);
  });

  test('GLM is the default NVIDIA model', () {
    expect(AiService.nvidiaDefaultModel, 'z-ai/glm-5.2');
    expect(AiService.nvidiaFreeChatModels.first, 'z-ai/glm-5.2');
  });

  group('parseAction', () {
    final ai = AiService();

    test('parses a plain JSON action', () {
      final action = ai.parseAction(
        '{"action": "execute_task", "params": {"goal": "sube 50 copas"}, "response": "ok"}',
      );
      expect(action, isNotNull);
      expect(action!.action, 'execute_task');
      expect(action.params['goal'], 'sube 50 copas');
    });

    test('parses JSON wrapped in code fences', () {
      final action = ai.parseAction(
        '```\n{"action": "open_app", "params": {"app_name": "Brawl Stars"}, "response": "Opening"}\n```',
      );
      expect(action, isNotNull);
      expect(action!.action, 'open_app');
      expect(action.params['app_name'], 'Brawl Stars');
    });

    test('recovers a truncated JSON missing its closing brace', () {
      final action = ai.parseAction(
        '{"action": "set_volume", "params": {"level": 50}, "response": "ok"',
      );
      expect(action, isNotNull);
      expect(action!.action, 'set_volume');
    });

    test('returns null for plain text conversation', () {
      expect(ai.parseAction('Sure, here is the answer for you.'), isNull);
    });
  });
}
