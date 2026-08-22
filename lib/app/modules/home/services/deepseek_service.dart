import 'dart:convert';
import 'dart:typed_data';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;

import 'ai_prompts.dart';

enum AiToolAction {
  translate('翻译'),
  explain('解释');

  const AiToolAction(this.label);

  final String label;
}

/// DeepSeek AI 服务：基于 Google Genkit (genkit_openai 插件) 接入
/// OpenAI 兼容的 DeepSeek API。
class DeepSeekService {
  DeepSeekService({
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  static const String apiKeyStorageKey = 'deepseek_api_key';
  static const String model = 'deepseek-v4-flash-vision-exp';
  static const String _endpoint = 'https://api.deepseek.com/v1';

  final http.Client? _httpClient;
  Genkit? _genkit;
  String? _genkitApiKey;

  /// 根据 API Key 获取（并缓存）Genkit 实例。
  ///
  /// API Key 变化时重建插件实例，避免在构建后无法更新凭据。
  Genkit _genkitFor(String apiKey) {
    final Genkit? cached = _genkit;
    if (cached != null && _genkitApiKey == apiKey) {
      return cached;
    }
    final Genkit genkit = Genkit(
      isDevEnv: false,
      plugins: [
        openAI(
          apiKey: apiKey,
          baseUrl: _endpoint,
          models: <CustomModelDefinition>[
            CustomModelDefinition(
              name: model,
              info: ModelInfo(
                label: 'DeepSeek Flash Vision',
                supports: <String, bool>{
                  'multiturn': true,
                  'tools': false,
                  'systemRole': true,
                  'media': true,
                },
              ),
            ),
          ],
          httpClient: _httpClient,
        ),
      ],
    );
    _genkit = genkit;
    _genkitApiKey = apiKey;
    return genkit;
  }

  /// 流式执行翻译/解释动作，逐块 yield 增量文本。
  Stream<String> performStream({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<Map<String, String>>? history,
    Uint8List? imageBytes,
  }) async* {
    final String normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      throw const DeepSeekException('请先填写 DeepSeek API Key。');
    }
    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
    if (selectionText.trim().isEmpty && !isVisionMode) {
      throw const DeepSeekException('请先框选内容。');
    }

    final List<Message> messages = <Message>[
      Message(
        role: Role.system,
        content: <Part>[TextPart(text: AiPrompts.systemPrompt(action))],
      ),
      ..._historyMessages(history),
    ];

    if (isVisionMode) {
      final String textContent = selectionText.trim().isEmpty
          ? AiPrompts.visionUserPrompt(action)
          : AiPrompts.userPrompt(action, selectionText, pageContext: pageContext);
      final String base64Image = base64Encode(imageBytes);
      messages.add(
        Message(
          role: Role.user,
          content: <Part>[
            TextPart(text: textContent),
            MediaPart(
              media: Media(
                contentType: 'image/png',
                url: 'data:image/png;base64,$base64Image',
              ),
            ),
          ],
        ),
      );
    } else {
      messages.add(
        Message(
          role: Role.user,
          content: <Part>[
            TextPart(
              text: AiPrompts.userPrompt(
                action,
                selectionText,
                pageContext: pageContext,
              ),
            ),
          ],
        ),
      );
    }

    yield* _generateStream(normalizedApiKey, messages);
  }

  /// 流式多轮对话，逐块 yield 增量文本。
  Stream<String> chatStream({
    required String apiKey,
    required List<Map<String, String>> history,
  }) async* {
    final String normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      throw const DeepSeekException('请先填写 DeepSeek API Key。');
    }
    if (history.isEmpty) {
      throw const DeepSeekException('对话内容不能为空。');
    }

    yield* _generateStream(
      normalizedApiKey,
      _historyMessages(history),
    );
  }

  /// 非流式执行翻译/解释动作（聚合流式结果）。
  Future<String> perform({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<Map<String, String>>? history,
    Uint8List? imageBytes,
  }) async {
    final StringBuffer buffer = StringBuffer();
    await for (final String chunk in performStream(
      action: action,
      apiKey: apiKey,
      selectionText: selectionText,
      pageContext: pageContext,
      history: history,
      imageBytes: imageBytes,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }

  /// 非流式多轮对话（聚合流式结果）。
  Future<String> chat({
    required String apiKey,
    required List<Map<String, String>> history,
  }) async {
    final StringBuffer buffer = StringBuffer();
    await for (final String chunk in chatStream(
      apiKey: apiKey,
      history: history,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }

  Stream<String> _generateStream(
    String apiKey,
    List<Message> messages,
  ) async* {
    final Genkit ai = _genkitFor(apiKey);
    try {
      await for (final GenerateResponseChunk<Object?> chunk in ai.generateStream(
        model: openAI.model(model),
        messages: messages,
      )) {
        final String text = chunk.text;
        if (text.isNotEmpty) {
          yield text;
        }
      }
    } on DeepSeekException {
      rethrow;
    } catch (error) {
      throw DeepSeekException(_normalizeError(error));
    }
  }

  List<Message> _historyMessages(List<Map<String, String>>? history) {
    if (history == null) {
      return <Message>[];
    }
    return history
        .map((Map<String, String> m) {
          final String role = m['role'] ?? 'user';
          return Message(
            role: role == 'assistant'
                ? Role.model
                : role == 'system'
                    ? Role.system
                    : Role.user,
            content: <Part>[TextPart(text: m['content'] ?? '')],
          );
        })
        .toList();
  }

  String _normalizeError(Object error) {
    final String message = error.toString();
    final String lowercased = message.toLowerCase();
    if (lowercased.contains('authentication') ||
        lowercased.contains('api key') ||
        lowercased.contains('invalid') ||
        lowercased.contains('401')) {
      return 'DeepSeek 认证失败：API Key 无效或授权不足。';
    }
    return 'DeepSeek 请求失败：$message';
  }
}

class DeepSeekException implements Exception {
  const DeepSeekException(this.message);

  final String message;

  @override
  String toString() => message;
}
