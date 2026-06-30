import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_prompts.dart';

enum AiToolAction {
  translate('翻译'),
  explain('解释');

  const AiToolAction(this.label);

  final String label;
}

class DeepSeekService {
  DeepSeekService({
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  static const String apiKeyStorageKey = 'deepseek_api_key';
  static const String model = 'deepseek-v4-flash';
  static const String _endpoint = 'https://api.deepseek.com/chat/completions';

  final http.Client _httpClient;

  Future<String> perform({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<Map<String, String>>? history,
  }) async {
    final String normalizedApiKey = apiKey.trim();
    if (normalizedApiKey.isEmpty) {
      throw const DeepSeekException('请先填写 DeepSeek API Key。');
    }
    if (selectionText.trim().isEmpty) {
      throw const DeepSeekException('请先框选内容。');
    }

    final List<Map<String, String>> messages = <Map<String, String>>[
      <String, String>{
        'role': 'system',
        'content': AiPrompts.systemPrompt(action),
      },
      if (history != null && history.isNotEmpty) ...history,
      if (history == null || history.isEmpty)
        <String, String>{
          'role': 'user',
          'content': AiPrompts.userPrompt(action, selectionText, pageContext: pageContext),
        },
    ];

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
      throw const DeepSeekException('请先填写 DeepSeek API Key。');
    }
    if (history.isEmpty) {
      throw const DeepSeekException('对话内容不能为空。');
    }

    final Map<String, Object?> payload = <String, Object?>{
      'model': model,
      'messages': history,
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
      throw DeepSeekException(_parseErrorMessage(response.body));
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const DeepSeekException('DeepSeek 响应格式无效。');
    }
    final List<dynamic>? choices = decoded['choices'] as List<dynamic>?;
    final Map<String, dynamic>? firstChoice =
        choices != null && choices.isNotEmpty ? choices.first as Map<String, dynamic>? : null;
    final Map<String, dynamic>? message =
        firstChoice?['message'] as Map<String, dynamic>?;
    final String content = (message?['content'] as String? ?? '').trim();
    if (content.isEmpty) {
      throw const DeepSeekException('DeepSeek 没有返回可展示的内容。');
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
      }
    } catch (_) {
      // ignore parse errors and fallback below
    }
    return 'DeepSeek 请求失败。';
  }

  String _normalizeError(String message) {
    final String lowercased = message.toLowerCase();
    if (lowercased.contains('authentication') ||
        lowercased.contains('api key') ||
        lowercased.contains('invalid')) {
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
