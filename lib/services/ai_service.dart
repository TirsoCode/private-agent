import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agent_action.dart';

class AiResponse {
  final String content;
  final int totalTokens;
  AiResponse(this.content, this.totalTokens);
}

class AiService {
  /// Compile-time OpenRouter API key, injected at build time via
  /// --dart-define=OPENROUTER_API_KEY=... (sourced from a GitHub secret).
  static const String _envOpenRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
  );

  static const String _defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const String _defaultModel = 'nvidia/nemotron-nano-12b-v2-vl:free';

  /// Endpoint that lists every model available on OpenRouter.
  static const String _modelsUrl = 'https://openrouter.ai/api/v1/models';

  /// Free model slugs that OpenRouter has removed. Any device still holding
  /// one of these (saved before removal) is reset to the current default.
  static const Set<String> _deprecatedModels = {
    'openai/gpt-oss-120b:free',
    'openai/gpt-oss-20b:free',
    'nvidia/nemotron-3-nano-30b-a3b:free',
  };

  /// Free models known to the app.
  ///
  /// This list serves as a local fallback/cache when the OpenRouter models
  /// endpoint cannot be reached, and to recognize free endpoints regardless of
  /// a `:free` suffix. The authoritative, always-up-to-date set is fetched at
  /// runtime via [fetchFreeModels].
  static const List<String> freeChatModels = [
    'cohere/north-mini-code:free',
    'dots-studio/dots-3-note-preview:free',
    'google/gemma-4-26b-a4b-it:free', // Gemma 4 26B A4B
    'google/gemma-4-31b-it:free',
    'inclusionai/ling-3.0-flash-fin:free',
    'liquid/lfm-2.5-2.6b:free',
    'minimax/minimax-m2.7:free',
    'minimax/minimax-m3:free',
    'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free', // Nemotron 3 Nano Omni
    'nvidia/nemotron-3-super-120b-a12b:free',
    'nvidia/nemotron-3-ultra-550b-a55b:free',
    'nvidia/nemotron-3.5-content-safety:free',
    'nvidia/nemotron-3.5-lightning:free',
    'nvidia/nemotron-nano-12b-v2-vl:free', // Nemotron Nano 2 VL 12B
    'poolside/laguna-s-2.1:free',
    'poolside/laguna-xs-2.1:free',
    'thinkingmachines/inkling-small:free',
    'thinkingmachines/inkling:free',
    'z-ai/glm-5.2:free',
  ];

  String? _apiKey;
  String _baseUrl = _defaultBaseUrl;
  String _model = _defaultModel;
  int _maxSteps = 200;
  bool _disableMaxSteps = false;
  double _temperature = 1.0;
  int _maxTokens = 1024;
  bool _useScreenCompression = true;
  bool _useSystemPrompt = true;
  final List<Map<String, String>> _conversationHistory = [];

  static const String _systemPrompt = '''
You are PrivateAgent, a helpful AI assistant that controls an Android phone. You can perform device actions and also have normal conversations.

When the user wants to perform a device action, you MUST respond with ONLY a JSON object (no markdown, no code fences, no extra text) in this exact format:
{"action": "action_name", "params": {"key": "value"}, "response": "What you say to the user"}

Available actions and their params:

SIMPLE ACTIONS (single step only):
- open_app: {"app_name": "YouTube"} - ONLY use this when the user JUST wants to open an app and nothing else
- make_call: {"contact_name": "Mom"} OR {"phone_number": "1234567890"} - Makes a phone call
- send_sms: {"contact_name": "John", "message": "Hello"} OR {"phone_number": "123", "message": "Hi"} - Sends SMS
- search_contact: {"query": "John"} - Searches contacts
- set_alarm: {"hour": 7, "minute": 30, "label": "Wake up"} - Sets an alarm
- set_volume: {"level": 50} - Sets volume (0-100)
- set_brightness: {"level": 50} - Sets brightness (0-100)
- read_screen: {} - Read what's currently on the screen
- press_back: {} - Press the back button

MULTI-STEP TASK (for anything that requires more than one action):
- execute_task: {"goal": "description of the full task"} - Automatically reads screen, taps, scrolls, types step by step

CRITICAL RULES:
1. If the user request contains "and" or involves MULTIPLE steps (open + search, open + send, open + find, etc.), you MUST use execute_task. NEVER use open_app for these.
2. execute_task handles everything: opening apps, finding elements, clicking, typing, scrolling.
3. Commands may come in ANY language (Spanish, English, etc.). Interpret the intent, not the language.
4. Gaming goals such as "juega al brawl stars y gana 50 copas" or "sube 50 copas con el brawler crow" are LONG multi-step tasks: ALWAYS use execute_task with the full goal.

Examples of when to use execute_task:
- "Create a new alarm for 7 AM" → execute_task with goal "Create a new alarm for 7 AM"
- "Go to YouTube and search for cats" → execute_task
- "Open WhatsApp and send hello to John" → execute_task
- "Open Settings and turn on WiFi" → execute_task
- "Search for restaurants on Google Maps" → execute_task
- "Juega al brawl stars y gana 50 copas" → execute_task with goal "Juega al brawl stars y gana 50 copas"
- "Sube 50 copas con el brawler crow" → execute_task with goal "Sube 50 copas con el brawler crow"

Examples of when to use open_app:
- "Open YouTube" → open_app (just opening, no further action)
- "Open Settings" → open_app (just opening)

For normal conversation (questions, chat, info requests), just respond with plain text naturally.
''';

  static const String _chatSystemPrompt = '''
You are PrivateAgent, a helpful conversational AI assistant. 
Provide direct, natural, and friendly text responses. You cannot perform device actions or run tools. 
Answer questions, explain concepts, brainstorm, write emails/messages, and chat with the user in plain text or markdown format.
''';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = _envOpenRouterApiKey.isNotEmpty
        ? _envOpenRouterApiKey
        : prefs.getString('api_key');
    final savedBaseUrl = prefs.getString('api_base_url');
    _baseUrl = (savedBaseUrl == null || savedBaseUrl.isEmpty)
        ? _defaultBaseUrl
        : _normalizeBaseUrl(savedBaseUrl);
    final savedModel = prefs.getString('api_model');
    _model =
        (savedModel == null ||
            savedModel.isEmpty ||
            _deprecatedModels.contains(savedModel))
        ? _defaultModel
        : savedModel;
    _maxSteps = prefs.getInt('api_max_steps') ?? 200;
    _disableMaxSteps = prefs.getBool('api_disable_max_steps') ?? false;
    _temperature = prefs.getDouble('api_temperature') ?? 1.0;
    _maxTokens = prefs.getInt('api_max_tokens') ?? 1024;
    _useScreenCompression = prefs.getBool('api_use_screen_compression') ?? true;
    _useSystemPrompt = prefs.getBool('api_use_system_prompt') ?? true;
  }

  /// Fetches the list of free models from OpenRouter.
  ///
  /// Consults the public models endpoint and filters for endpoint IDs ending in
  /// `:free` (remembering to also accept models whose pricing is zero even if
  /// they lack the suffix). Returns a deduplicated, sorted list of model IDs.
  /// A model is considered free when both its prompt and completion prices are 0.
  Future<List<String>> fetchFreeModels() async {
    try {
      final response = await http
          .get(Uri.parse(_modelsUrl))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        developer.log(
          'fetchFreeModels: HTTP ${response.statusCode}: ${response.body}',
          name: 'AiService',
        );
        return freeChatModels;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['data'] is! List) {
        developer.log(
          'fetchFreeModels: unexpected payload shape',
          name: 'AiService',
        );
        return freeChatModels;
      }

      final result = <String>{};
      for (final item in data['data'] as List) {
        if (item is! Map<String, dynamic>) continue;
        final modelId = item['id'];
        if (modelId is! String || modelId.isEmpty) continue;

        final isFreeSuffix = modelId.endsWith(':free');
        final pricing = item['pricing'];
        final promptPrice = pricing is Map<String, dynamic>
            ? pricing['prompt']?.toString()
            : null;
        final completionPrice = pricing is Map<String, dynamic>
            ? pricing['completion']?.toString()
            : null;
        final isZeroPriced = _isZeroPrice(promptPrice) &&
            _isZeroPrice(completionPrice);

        if (isFreeSuffix || isZeroPriced) {
          result.add(modelId);
        }
      }

      final list = result.toList()..sort();
      return list.isEmpty ? freeChatModels : list;
    } catch (e) {
      developer.log('fetchFreeModels failed: $e', name: 'AiService');
      return freeChatModels;
    }
  }

  static bool _isZeroPrice(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      return double.parse(raw) == 0.0;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSettings({
    String? apiKey,
    String? model,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (apiKey != null && apiKey.isNotEmpty) {
      // Clean up the API key in case the user pasted "Bearer sk-..."
      String cleanApiKey = apiKey.trim();
      if (cleanApiKey.toLowerCase().startsWith('bearer ')) {
        cleanApiKey = cleanApiKey.substring(7).trim();
      }
      _apiKey = cleanApiKey;
      await prefs.setString('api_key', cleanApiKey);
    }
    if (model != null && model.isNotEmpty) {
      _model = model;
      await prefs.setString('api_model', model);
    }
    if (baseUrl != null && baseUrl.isNotEmpty) {
      final normalized = _normalizeBaseUrl(baseUrl);
      _baseUrl = normalized;
      await prefs.setString('api_base_url', normalized);
    }
  }

  /// Strip trailing slashes so building the `/chat/completions` suffix works.
  static String _normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<void> saveMaxSteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    _maxSteps = steps;
    await prefs.setInt('api_max_steps', steps);
  }

  Future<void> saveDisableMaxSteps(bool disable) async {
    final prefs = await SharedPreferences.getInstance();
    _disableMaxSteps = disable;
    await prefs.setBool('api_disable_max_steps', disable);
  }

  Future<void> saveAdvancedSettings({
    required double temperature,
    required int maxTokens,
    required bool useScreenCompression,
    required bool useSystemPrompt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _temperature = temperature;
    _maxTokens = maxTokens;
    _useScreenCompression = useScreenCompression;
    _useSystemPrompt = useSystemPrompt;
    await prefs.setDouble('api_temperature', temperature);
    await prefs.setInt('api_max_tokens', maxTokens);
    await prefs.setBool('api_use_screen_compression', useScreenCompression);
    await prefs.setBool('api_use_system_prompt', useSystemPrompt);
  }

  bool get isConfigured {
    if (_apiKey != null && _apiKey!.isNotEmpty) return true;
    // Local model servers (Ollama, LM Studio, llama.cpp...) need no API key.
    return _isLocalEndpoint(_baseUrl);
  }

  /// True when the target host looks like a local/private model server.
  bool _isLocalEndpoint(String url) {
    try {
      final host = Uri.parse(_normalizeBaseUrl(url)).host.toLowerCase();
      return host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1' ||
          host.startsWith('192.168.') ||
          host.startsWith('10.') ||
          host.startsWith('172.') ||
          host.endsWith('.local');
    } catch (_) {
      return false;
    }
  }

  /// Throws only when the user must enter a key or pick a local endpoint.
  void _ensureConfigured() {
    if (_apiKey == null || _apiKey!.isEmpty) {
      if (_isLocalEndpoint(_baseUrl)) return;
      throw Exception(
        'No API key configured. Add a key or point the Base URL to a local '
        'model server (e.g. http://localhost:11434).',
      );
    }
  }

  String get baseUrl => _baseUrl;
  String get model => _model;
  String get apiKey => _apiKey ?? '';
  // When "disable max steps" is on there is effectively no limit, so the agent
  // can run long goals (e.g. grinding trophies) without being cut off.
  int get maxSteps => _disableMaxSteps ? 100000 : _maxSteps;
  int get rawMaxSteps => _maxSteps; // For the slider UI
  bool get disableMaxSteps => _disableMaxSteps;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;
  bool get useScreenCompression => _useScreenCompression;
  bool get useSystemPrompt => _useSystemPrompt;

  int get _effectiveMaxTokens {
    // Reasoning models can burn the whole 1,024-token default budget thinking
    // and finish without visible content, so guarantee a larger minimum.
    if (_isFreeModel(_model) && _maxTokens < 4096) {
      return 4096;
    }
    return _maxTokens;
  }

  /// True when the current model is a free OpenRouter endpoint (either a
  /// `:free` slug or one of the hardcoded free options).
  bool _isFreeModel(String modelId) {
    if (modelId.endsWith(':free')) return true;
    return freeChatModels.contains(modelId);
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  void addHistoryMessage(String role, String content) {
    _conversationHistory.add({'role': role, 'content': content});
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }
  }

  /// Send a message to the AI and get a response.
  Future<String> sendMessage(String message, {bool isAgentMode = true}) async {
    _ensureConfigured();
    // Add ONLY the text to the persistent conversation history to save tokens.
    _conversationHistory.add({'role': 'user', 'content': message});

    // Keep conversation history manageable (last 20 messages)
    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }

    try {
      // Build the prompt including system instructions
      final systemPrompt = isAgentMode ? _systemPrompt : _chatSystemPrompt;
      final messages = [
        if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
        ..._conversationHistory,
      ];

      String requestUrl = _baseUrl;
      if (requestUrl.endsWith('/chat/completions')) {
        requestUrl = requestUrl; // User already included it
      } else {
        if (requestUrl.endsWith('/')) {
          requestUrl = '${requestUrl}chat/completions';
        } else {
          requestUrl = '$requestUrl/chat/completions';
        }
      }

      final requestBody = jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': _temperature,
        'max_tokens': _effectiveMaxTokens,
      });

      developer.log(
        'API Request: $requestUrl\n$requestBody',
        name: 'AiService',
      );

      final response = await http
          .post(
            Uri.parse(requestUrl),
            headers: {
              'Content-Type': 'application/json',
              if (_apiKey != null && _apiKey!.isNotEmpty)
                'Authorization': 'Bearer $_apiKey',
              'HTTP-Referer': 'https://github.com/Tirso54/private-agent',
              'X-Title': 'PrivateAgent',
            },
            body: requestBody,
          )
          .timeout(const Duration(minutes: 30));

      developer.log(
        'API Response [${response.statusCode}]: ${response.body}',
        name: 'AiService',
      );

      if (response.statusCode != 200) {
        String errorMessage = response.body;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['error'] is Map<String, dynamic>) {
              errorMessage =
                  decoded['error']['message']?.toString() ?? response.body;
            } else if (decoded['error'] is String) {
              errorMessage = decoded['error'];
            }
          }
        } catch (_) {
          // ignore parsing errors, use raw body
        }
        throw Exception('API error (${response.statusCode}): $errorMessage');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || !data.containsKey('choices')) {
        throw Exception('Unexpected API response format: $data');
      }

      String assistantMessage =
          data['choices'][0]['message']['content'] as String;

      // Strip <think> blocks commonly produced by reasoning models
      assistantMessage = assistantMessage
          .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
          .trim();

      if (assistantMessage.trim().isEmpty) {
        throw Exception(
          'API returned an empty response. This may be due to rate limits or API instability.',
        );
      }

      _conversationHistory.add({
        'role': 'assistant',
        'content': assistantMessage,
      });

      return assistantMessage;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Send a message and stream the response chunk-by-chunk.
  Stream<String> sendMessageStream(
    String message, {
    bool isAgentMode = true,
  }) async* {
    _ensureConfigured();

    _conversationHistory.add({'role': 'user', 'content': message});

    if (_conversationHistory.length > 20) {
      _conversationHistory.removeRange(0, _conversationHistory.length - 20);
    }

    try {
      final systemPrompt = isAgentMode ? _systemPrompt : _chatSystemPrompt;
      final messages = [
        if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
        ..._conversationHistory,
      ];

      String requestUrl = _baseUrl;
      if (requestUrl.endsWith('/chat/completions')) {
        requestUrl = requestUrl;
      } else {
        if (requestUrl.endsWith('/')) {
          requestUrl = '${requestUrl}chat/completions';
        } else {
          requestUrl = '$requestUrl/chat/completions';
        }
      }

      final client = http.Client();
      final request = http.Request('POST', Uri.parse(requestUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        if (_apiKey != null && _apiKey!.isNotEmpty)
          'Authorization': 'Bearer $_apiKey',
        'HTTP-Referer': 'https://github.com/Tirso54/private-agent',
        'X-Title': 'PrivateAgent',
      });

      request.body = jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': _temperature,
        'max_tokens': _effectiveMaxTokens,
        'stream': true,
      });

      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 30));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String errorMessage = body;
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['error'] is Map<String, dynamic>) {
              errorMessage = decoded['error']['message']?.toString() ?? body;
            } else if (decoded['error'] is String) {
              errorMessage = decoded['error'];
            }
          }
        } catch (_) {}
        client.close();
        throw Exception('API error (${response.statusCode}): $errorMessage');
      }

      final accumulatedContent = StringBuffer();
      bool inThinkBlock = false;

      // Listen to response stream
      final lineStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        if (trimmedLine.startsWith('data:')) {
          final dataStr = trimmedLine.substring(5).trim();
          if (dataStr == '[DONE]') break;
          try {
            final json = jsonDecode(dataStr);
            if (json is Map && json['choices'] is List) {
              final choices = json['choices'] as List;
              if (choices.isNotEmpty) {
                final choice = choices[0];
                if (choice is! Map) continue;
                final rawDelta = choice['delta'];
                final delta = rawDelta is Map ? rawDelta : const {};
                final rawContent = delta['content'];
                if (rawContent is String && rawContent.isNotEmpty) {
                  final content = rawContent;
                  accumulatedContent.write(content);

                  // Handle <think> block stripping on the fly for better stream styling
                  if (content.contains('<think>')) {
                    inThinkBlock = true;
                    // If there is text before <think>, yield it
                    final parts = content.split('<think>');
                    if (parts[0].isNotEmpty) {
                      yield parts[0];
                    }
                  } else if (content.contains('</think>')) {
                    inThinkBlock = false;
                    // If there is text after </think>, yield it
                    final parts = content.split('</think>');
                    if (parts.length > 1 && parts[1].isNotEmpty) {
                      yield parts[1];
                    }
                  } else if (!inThinkBlock) {
                    yield content;
                  }
                }
                if (choice['finish_reason'] != null) break;
              }
            }
          } catch (_) {
            // Ignore incomplete chunks
          }
        }
      }

      client.close();

      // Clean up final accumulated response and add to history
      String finalResponse = accumulatedContent.toString().trim();
      finalResponse = finalResponse
          .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
          .trim();

      if (finalResponse.isEmpty) {
        throw Exception(
          'The model finished without a visible answer. Increase Max Tokens '
          'or try another model.',
        );
      }
      _conversationHistory.add({'role': 'assistant', 'content': finalResponse});
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error: $e');
    }
  }

  /// Send a task execution message — no conversation history, low temperature, limited tokens.
  /// This is much faster and cheaper than sendMessage.
  Future<AiResponse> sendTaskMessage(String systemPrompt, String prompt) async {
    _ensureConfigured();

    int maxRetries = 4;
    int currentTry = 0;

    while (true) {
      try {
        currentTry++;
        final messages = [
          if (_useSystemPrompt) {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt},
        ];

        String requestUrl = _baseUrl;
        if (!requestUrl.endsWith('/chat/completions')) {
          if (requestUrl.endsWith('/')) {
            requestUrl = '${requestUrl}chat/completions';
          } else {
            requestUrl = '$requestUrl/chat/completions';
          }
        }

        final response = await http
            .post(
              Uri.parse(requestUrl),
              headers: {
                'Content-Type': 'application/json',
                if (_apiKey != null && _apiKey!.isNotEmpty)
                  'Authorization': 'Bearer $_apiKey',
                'HTTP-Referer': 'https://github.com/Tirso54/private-agent',
                'X-Title': 'PrivateAgent',
              },
              body: jsonEncode({
                'model': _model,
                'messages': messages,
                'temperature': _temperature,
                'max_tokens': _effectiveMaxTokens,
              }),
            )
            .timeout(const Duration(minutes: 30));

        if (response.statusCode != 200) {
          String errorMessage = response.body;
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              if (decoded['error'] is Map<String, dynamic>) {
                errorMessage = decoded['error']['message'] ?? response.body;
              } else if (decoded['error'] is String) {
                errorMessage = decoded['error'];
              }
            }
          } catch (_) {
            // ignore parsing errors, use raw body
          }
          throw Exception('API error (${response.statusCode}): $errorMessage');
        }

        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic> || !data.containsKey('choices')) {
          throw Exception('Unexpected API response format: $data');
        }
        String content = data['choices'][0]['message']['content'] as String;

        // Strip <think> blocks commonly produced by reasoning models
        content = content
            .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
            .trim();

        if (content.trim().isEmpty) {
          throw Exception(
            'API returned an empty response. This may be due to strict rate limits or safety filters.',
          );
        }

        int tokens = 0;
        if (data.containsKey('usage') &&
            data['usage']['total_tokens'] != null) {
          tokens = data['usage']['total_tokens'] as int;
        }
        return AiResponse(content, tokens);
      } catch (e) {
        if (currentTry > maxRetries) {
          if (e is Exception) rethrow;
          throw Exception('Network error after $maxRetries retries: $e');
        }
        int delaySeconds = 3 * currentTry;
        developer.log(
          'API call failed ($e), retrying $currentTry/$maxRetries in $delaySeconds seconds...',
          name: 'PrivateAgent',
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  /// Parse the AI response to check if it's an action or plain text
  AgentAction? parseAction(String response) {
    // Try to parse as JSON action
    try {
      final trimmed = response.trim();
      // Handle if the response is wrapped in code fences
      String jsonStr = trimmed;
      if (trimmed.startsWith('```')) {
        final lines = trimmed.split('\n');
        lines.removeAt(0); // Remove opening fence
        if (lines.isNotEmpty && lines.last.trim() == '```') {
          lines.removeLast(); // Remove closing fence
        }
        jsonStr = lines.join('\n').trim();
      }

      // If it looks like JSON but is missing a closing brace (common with some local models)
      if (jsonStr.startsWith('{') && !jsonStr.endsWith('}')) {
        jsonStr += '\n}';
      }

      if (jsonStr.startsWith('{') && jsonStr.contains('"action"')) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (json.containsKey('action')) {
            return AgentAction.fromJson(json);
          }
        } catch (e) {
          // If it still fails, it might be deeply truncated, try adding another brace
          if (e.toString().contains('Unexpected end of input')) {
            jsonStr += '\n}';
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (json.containsKey('action')) {
              return AgentAction.fromJson(json);
            }
          }
        }
      }
    } catch (_) {
      // Not JSON, it's plain text conversation
    }
    return null;
  }
}
