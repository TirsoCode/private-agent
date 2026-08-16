import 'package:flutter_test/flutter_test.dart';
import 'package:private_agent/services/ai_service.dart';

void main() {
  test('free model list offers only the three supported OpenRouter models', () {
    expect(AiService.freeChatModels, [
      'nvidia/nemotron-nano-12b-v2-vl:free',
      'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
      'google/gemma-4-26b-a4b-it:free',
    ]);
  });

  test('free model list contains the new default model', () {
    expect(
      AiService.freeChatModels,
      contains('nvidia/nemotron-nano-12b-v2-vl:free'),
    );
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
