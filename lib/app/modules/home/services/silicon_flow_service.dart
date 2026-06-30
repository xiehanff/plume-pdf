import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'ai_prompts.dart';

class SiliconFlowService {
  SiliconFlowService({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  static const String apiKeyStorageKey = 'silicon_flow_api_key';
  static const String model = 'Qwen/Qwen3-VL-30B-A3B-Instruct';
  static const String _endpoint = 'https://api.siliconflow.cn/v1/chat/completions';

  final http.Client _httpClient;

  Future<String> perform({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<Map<String, String>>? history,
    Uint8List? imageBytes,
  }) async {
    final String normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      throw const SiliconFlowException('请先填写硅基流动 API Key。');
    }
    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
    if (selectionText.trim().isEmpty && !isVisionMode) {
      throw const SiliconFlowException('请先框选内容。');
    }

    final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[
      <String, String>{
        'role': 'system',
        'content': AiPrompts.systemPrompt(action),
      },
      if (history != null && history.isNotEmpty)
        ...history.map((Map<String, String> m) => <String, String>{
              'role': m['role']!,
              'content': m['content']!,
            }),
    ];

    if (imageBytes != null && imageBytes.isNotEmpty) {
      final String textContent = selectionText.trim().isEmpty
          ? AiPrompts.visionUserPrompt(action)
          : AiPrompts.userPrompt(action, selectionText, pageContext: pageContext);
      final String base64Image = base64Encode(imageBytes);
      messages.add(<String, dynamic>{
        'role': 'user',
        'content': <Map<String, dynamic>>[
          <String, String>{
            'type': 'text',
            'text': textContent,
          },
          <String, dynamic>{
            'type': 'image_url',
            'image_url': <String, String>{
              'url': 'data:image/png;base64,$base64Image',
            },
          },
        ],
      });
    } else {
      messages.add(<String, String>{
        'role': 'user',
        'content': AiPrompts.userPrompt(action, selectionText, pageContext: pageContext),
      });
    }

    final Map<String, Object?> payload = <String, Object?>{
      'model': model,
      'messages': messages,
    };

    return _sendRequest(normalizedApiKey, payload);
  }

  Future<String> chat({
    required String apiKey,
    required List<Map<String, String>> history,
  }) async {
    final String normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      throw const SiliconFlowException('请先填写硅基流动 API Key。');
    }
    if (history.isEmpty) {
      throw const SiliconFlowException('对话内容不能为空。');
    }

    final List<Map<String, dynamic>> messages = history
        .map((Map<String, String> m) => <String, String>{
              'role': m['role']!,
              'content': m['content']!,
            })
        .toList();

    final Map<String, Object?> payload = <String, Object?>{
      'model': model,
      'messages': messages,
    };

    return _sendRequest(normalizedApiKey, payload);
  }

  Future<String> _sendRequest(String apiKey, Map<String, Object?> payload) async {
    final http.Response response = await _httpClient.post(
      Uri.parse(_endpoint),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SiliconFlowException(_parseErrorMessage(response.body));
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const SiliconFlowException('硅基流动响应格式无效。');
    }
    final List<dynamic>? choices = decoded['choices'] as List<dynamic>?;
    final Map<String, dynamic>? firstChoice =
        choices != null && choices.isNotEmpty ? choices.first as Map<String, dynamic>? : null;
    final Map<String, dynamic>? message =
        firstChoice?['message'] as Map<String, dynamic>?;
    final String content = (message?['content'] as String? ?? '').trim();
    if (content.isEmpty) {
      throw const SiliconFlowException('硅基流动没有返回可展示的内容。');
    }
    return content;
  }

  String _parseErrorMessage(String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final Object? error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final String message = (error['message'] as String? ?? '').trim();
          if (message.isNotEmpty) {
            return _normalizeError(message);
          }
        }
        final String? message = decoded['message'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          return '硅基流动请求失败：$message';
        }
      }
    } catch (_) {}
    return '硅基流动请求失败。';
  }

  String _normalizeError(String message) {
    final String lowercased = message.toLowerCase();
    if (lowercased.contains('authentication') ||
        lowercased.contains('api key') ||
        lowercased.contains('invalid')) {
      return '硅基流动认证失败：API Key 无效或授权不足。';
    }
    return '硅基流动请求失败：$message';
  }
}

class SiliconFlowException implements Exception {
  const SiliconFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}
