import 'dart:convert';
import 'dart:typed_data';

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

/// DeepSeek SSE 返回的一小段增量。正文与推理过程分别累积，
/// 由上层决定如何展示。
class DeepSeekStreamChunk {
  const DeepSeekStreamChunk({this.text = '', this.reasoning = ''});

  final String text;
  final String reasoning;
}

/// DeepSeek OpenAI-compatible HTTP/SSE transport。
class DeepSeekService {
  DeepSeekService({http.Client? httpClient}) : _httpClient = httpClient;

  static const String apiKeyStorageKey = 'deepseek_api_key';
  static const String model = 'deepseek-v4-flash-vision-exp';
  static const String _endpoint = 'https://api.deepseek.com/v1';
  static const int _deepDiveMaxTokens = 32768;
  static const String _lightReasoningEffort = 'low';

  final http.Client? _httpClient;

  Stream<DeepSeekStreamChunk> performStream({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
    Uint8List? imageBytes,
  }) async* {
    final String normalizedApiKey = _requireApiKey(apiKey);
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
      reasoningEffort: action == AiToolAction.deepDive
          ? null
          : _lightReasoningEffort,
    );
  }

  Stream<DeepSeekStreamChunk> chatStream({
    required String apiKey,
    required List<AiChatHistoryMessage> history,
    PdfAiContext? documentContext,
  }) async* {
    final String normalizedApiKey = _requireApiKey(apiKey);
    if (history.isEmpty) {
      throw const DeepSeekException('对话内容不能为空。');
    }

    yield* _generateHttpStream(
      normalizedApiKey,
      _chatMessages(history, documentContext: documentContext),
      reasoningEffort: _lightReasoningEffort,
    );
  }

  String _requireApiKey(String apiKey) {
    final String normalized = apiKey.trim();
    if (normalized.isEmpty) {
      throw const DeepSeekException('请先填写 DeepSeek API Key。');
    }
    return normalized;
  }

  Stream<DeepSeekStreamChunk> _generateHttpStream(
    String apiKey,
    List<Map<String, dynamic>> messages, {
    int? maxTokens,
    String? reasoningEffort,
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
              'messages': messages,
              'stream': true,
              if (maxTokens != null) 'max_tokens': maxTokens,
              if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
            });

      final http.StreamedResponse response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final String body = await response.stream.bytesToString();
        throw DeepSeekException(
          _normalizeError('HTTP ${response.statusCode}: $body'),
          statusCode: response.statusCode,
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

  List<Map<String, dynamic>> _performMessages({
    required AiToolAction action,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
    Uint8List? imageBytes,
  }) {
    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
    final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[
      _textMessage('system', AiPrompts.systemPrompt(action)),
      ..._historyMessages(history),
    ];

    if (!isVisionMode) {
      messages.add(
        _textMessage(
          'user',
          AiPrompts.userPrompt(
            action,
            selectionText,
            pageContext: pageContext,
          ),
        ),
      );
      return messages;
    }

    final String textContent = selectionText.trim().isEmpty
        ? AiPrompts.visionUserPrompt(action)
        : AiPrompts.userPrompt(
            action,
            selectionText,
            pageContext: pageContext,
          );
    messages.add(
      <String, dynamic>{
        'role': 'user',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': textContent},
          _imagePart('image/png', imageBytes),
        ],
      },
    );
    return messages;
  }

  List<Map<String, dynamic>> _chatMessages(
    List<AiChatHistoryMessage> history, {
    PdfAiContext? documentContext,
  }) {
    return <Map<String, dynamic>>[
      _textMessage(
        'system',
        AiPrompts.chatSystemPrompt(documentContext: documentContext),
      ),
      ..._historyMessages(history),
    ];
  }

  List<Map<String, dynamic>> _historyMessages(
    List<AiChatHistoryMessage>? history,
  ) {
    if (history == null) {
      return <Map<String, dynamic>>[];
    }
    return history.map((AiChatHistoryMessage message) {
      final AiImageAttachment? image = message.image;
      final bool hasImage = image?.bytes.isNotEmpty ?? false;
      final String role = switch (message.role) {
        AiChatHistoryRole.assistant => 'assistant',
        AiChatHistoryRole.system => 'system',
        AiChatHistoryRole.user => 'user',
      };
      final String text = message.content.trim().isEmpty && hasImage
          ? '请分析这张图片。'
          : message.content;
      if (!hasImage) {
        return _textMessage(role, text);
      }
      return <String, dynamic>{
        'role': role,
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'text', 'text': text},
          _imagePart(image!.mimeType, image.bytes),
        ],
      };
    }).toList();
  }

  Map<String, dynamic> _textMessage(String role, String text) {
    return <String, dynamic>{'role': role, 'content': text};
  }

  Map<String, dynamic> _imagePart(String mimeType, Uint8List bytes) {
    return <String, dynamic>{
      'type': 'image_url',
      'image_url': <String, dynamic>{
        'url': 'data:$mimeType;base64,${base64Encode(bytes)}',
      },
    };
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
  const DeepSeekException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get canFallbackToText {
    if (statusCode != 400 && statusCode != 422) {
      return false;
    }
    final String lowercased = message.toLowerCase();
    return lowercased.contains('image') ||
        lowercased.contains('vision') ||
        lowercased.contains('media') ||
        lowercased.contains('multimodal');
  }

  @override
  String toString() => message;
}
