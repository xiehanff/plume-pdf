import 'dart:convert';
import 'dart:typed_data';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;

import '../models/ai_chat_history_message.dart';
import '../models/ai_chat_input.dart';
import '../models/pdf_ai_context.dart';
import 'ai_prompts.dart';

enum AiToolAction {
  translate('翻译'),
  explain('解释'),
  deepDive('深度理解');

  const AiToolAction(this.label);

  final String label;
}

/// DeepSeek 兼容流式接口返回的一小段增量。
///
/// Genkit 的 OpenAI 适配器目前只暴露正文文本，会丢弃
/// `reasoning_content`。c 工作树使用直接 SSE 解析，因此把两类内容
/// 明确分开，交给 UI 分别展示。
class DeepSeekStreamChunk {
  const DeepSeekStreamChunk({this.text = '', this.reasoning = ''});

  final String text;
  final String reasoning;
}

/// DeepSeek AI 服务：基于 Google Genkit (genkit_openai 插件) 接入
/// OpenAI 兼容的 DeepSeek API。
class DeepSeekService {
  DeepSeekService({http.Client? httpClient}) : _httpClient = httpClient;

  static const String apiKeyStorageKey = 'deepseek_api_key';
  static const String model = 'deepseek-v4-flash-vision-exp';
  static const String _endpoint = 'https://api.deepseek.com/v1';
  // DeepSeek 的 completion token 预算同时包含推理过程和正式答案。
  // 4K 容易在长推理后只剩标题，因此为深度理解预留 32K。
  static const int _deepDiveMaxTokens = 32768;

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
    List<AiChatHistoryMessage>? history,
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

    final List<Message> messages = _performMessages(
      action: action,
      selectionText: selectionText,
      pageContext: pageContext,
      history: history,
      imageBytes: imageBytes,
    );

    yield* _generateStream(
      normalizedApiKey,
      messages,
      config: action == AiToolAction.deepDive
          ? OpenAIChatOptions(maxTokens: _deepDiveMaxTokens)
          : null,
    );
  }

  /// 流式多轮对话，逐块 yield 增量文本。
  Stream<String> chatStream({
    required String apiKey,
    required List<AiChatHistoryMessage> history,
    PdfAiContext? documentContext,
  }) async* {
    final String normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      throw const DeepSeekException('请先填写 DeepSeek API Key。');
    }
    if (history.isEmpty) {
      throw const DeepSeekException('对话内容不能为空。');
    }

    yield* _generateStream(normalizedApiKey, <Message>[
      Message(
        role: Role.system,
        content: <Part>[
          TextPart(
            text: AiPrompts.chatSystemPrompt(documentContext: documentContext),
          ),
        ],
      ),
      ..._historyMessages(history),
    ]);
  }

  /// 直接读取 DeepSeek SSE 中的正文和 `reasoning_content` 增量。
  ///
  /// 现有 Genkit 流接口继续保留给旧调用方；需要展示推理过程的调用方
  /// 使用此方法，避免适配层把 reasoning 字段静默丢掉。
  Stream<DeepSeekStreamChunk> performStreamWithReasoning({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
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

    yield* _generateHttpStream(
      normalizedApiKey,
      _performMessages(
        action: action,
        selectionText: selectionText,
        pageContext: pageContext,
        history: history,
        imageBytes: imageBytes,
      ),
      maxTokens: action == AiToolAction.deepDive ? _deepDiveMaxTokens : null,
    );
  }

  /// 直接读取多轮对话中的正文和 `reasoning_content` 增量。
  Stream<DeepSeekStreamChunk> chatStreamWithReasoning({
    required String apiKey,
    required List<AiChatHistoryMessage> history,
    PdfAiContext? documentContext,
  }) async* {
    final String normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      throw const DeepSeekException('请先填写 DeepSeek API Key。');
    }
    if (history.isEmpty) {
      throw const DeepSeekException('对话内容不能为空。');
    }

    yield* _generateHttpStream(
      normalizedApiKey,
      _chatMessages(history, documentContext: documentContext),
    );
  }

  /// 非流式执行翻译/解释动作（聚合流式结果）。
  Future<String> perform({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
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
    required List<AiChatHistoryMessage> history,
    PdfAiContext? documentContext,
  }) async {
    final StringBuffer buffer = StringBuffer();
    await for (final String chunk in chatStream(
      apiKey: apiKey,
      history: history,
      documentContext: documentContext,
    )) {
      buffer.write(chunk);
    }
    return buffer.toString().trim();
  }

  Stream<String> _generateStream(
    String apiKey,
    List<Message> messages, {
    OpenAIChatOptions? config,
  }) async* {
    final Genkit ai = _genkitFor(apiKey);
    try {
      await for (final GenerateResponseChunk<Object?> chunk
          in ai.generateStream(
            model: openAI.model(model),
            messages: messages,
            config: config,
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

  Stream<DeepSeekStreamChunk> _generateHttpStream(
    String apiKey,
    List<Message> messages, {
    int? maxTokens,
  }) async* {
    final http.Client client = _httpClient ?? http.Client();
    final bool closeClient = _httpClient == null;
    try {
      final http.Request request =
          http.Request('POST', Uri.parse('$_endpoint/chat/completions'))
            ..headers.addAll(<String, String>{
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
            })
            ..body = jsonEncode(<String, dynamic>{
              'model': model,
              'messages': messages.map(_messageToOpenAiJson).toList(),
              'stream': true,
              if (maxTokens != null) 'max_tokens': maxTokens,
            });

      final http.StreamedResponse response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String body = await response.stream.bytesToString();
        throw DeepSeekException(
          _normalizeError('HTTP ${response.statusCode}: $body'),
        );
      }

      await for (final String line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) {
          continue;
        }
        final String data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') {
          continue;
        }
        final Object? decoded;
        try {
          decoded = jsonDecode(data);
        } on FormatException {
          continue;
        }
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final Object? rawChoices = decoded['choices'];
        if (rawChoices is! List || rawChoices.isEmpty) {
          continue;
        }
        final Object? rawChoice = rawChoices.first;
        if (rawChoice is! Map<String, dynamic>) {
          continue;
        }
        final Object? rawDelta = rawChoice['delta'];
        if (rawDelta is! Map<String, dynamic>) {
          continue;
        }

        final String reasoning = _firstString(rawDelta, <String>[
          'reasoning_content',
          'reasoning',
          'thinking',
          'thought',
        ]);
        final String text = _stringValue(rawDelta['content']);
        if (reasoning.isNotEmpty || text.isNotEmpty) {
          yield DeepSeekStreamChunk(text: text, reasoning: reasoning);
        }
      }
    } on DeepSeekException {
      rethrow;
    } catch (error) {
      throw DeepSeekException(_normalizeError(error));
    } finally {
      if (closeClient) {
        client.close();
      }
    }
  }

  List<Message> _performMessages({
    required AiToolAction action,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
    Uint8List? imageBytes,
  }) {
    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
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
          : AiPrompts.userPrompt(
              action,
              selectionText,
              pageContext: pageContext,
            );
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
    return messages;
  }

  List<Message> _chatMessages(
    List<AiChatHistoryMessage> history, {
    PdfAiContext? documentContext,
  }) {
    return <Message>[
      Message(
        role: Role.system,
        content: <Part>[
          TextPart(
            text: AiPrompts.chatSystemPrompt(documentContext: documentContext),
          ),
        ],
      ),
      ..._historyMessages(history),
    ];
  }

  Map<String, dynamic> _messageToOpenAiJson(Message message) {
    final String role = switch (message.role.value) {
      'model' => 'assistant',
      'tool' => 'tool',
      'system' => 'system',
      _ => 'user',
    };
    final List<Map<String, dynamic>> parts = <Map<String, dynamic>>[];
    for (final Part part in message.content) {
      if (part.isText) {
        parts.add(<String, dynamic>{'type': 'text', 'text': part.text ?? ''});
      } else if (part.isMedia && part.media != null) {
        final Media media = part.media!;
        parts.add(<String, dynamic>{
          'type': 'image_url',
          'image_url': <String, dynamic>{'url': media.url},
        });
      }
    }
    final Object content = parts.length == 1 && parts.first['type'] == 'text'
        ? parts.first['text'] as String
        : parts;
    return <String, dynamic>{'role': role, 'content': content};
  }

  String _firstString(Map<String, dynamic> values, List<String> keys) {
    for (final String key in keys) {
      final String value = _stringValue(values[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  String _stringValue(Object? value) => value is String ? value : '';

  List<Message> _historyMessages(List<AiChatHistoryMessage>? history) {
    if (history == null) {
      return <Message>[];
    }
    return history.map((AiChatHistoryMessage message) {
      final AiImageAttachment? image = message.image;
      final bool hasImage = image?.bytes.isNotEmpty ?? false;
      final List<Part> content = <Part>[
        TextPart(
          text: message.content.trim().isEmpty && hasImage
              ? '请分析这张图片。'
              : message.content,
        ),
      ];
      if (hasImage) {
        final AiImageAttachment attachment = image!;
        final String base64Image = base64Encode(attachment.bytes);
        content.add(
          MediaPart(
            media: Media(
              contentType: attachment.mimeType,
              url: 'data:${attachment.mimeType};base64,$base64Image',
            ),
          ),
        );
      }
      return Message(
        role: switch (message.role) {
          AiChatHistoryRole.assistant => Role.model,
          AiChatHistoryRole.system => Role.system,
          AiChatHistoryRole.user => Role.user,
        },
        content: content,
      );
    }).toList();
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
