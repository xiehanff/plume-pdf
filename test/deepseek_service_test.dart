import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plume_pdf/app/modules/home/services/deepseek_service.dart';

/// 构造 OpenAI 兼容 SSE 响应体（UTF-8 bytes）。
http.Response sseResponse(List<String> chunks, {int statusCode = 200}) {
  final StringBuffer buffer = StringBuffer();
  for (final String chunk in chunks) {
    buffer
      ..write('data: ')
      ..write(
        jsonEncode(<String, dynamic>{
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{
              'delta': <String, String>{'content': chunk},
            },
          ],
        }),
      )
      ..write('\n\n');
  }
  buffer.write('data: [DONE]\n\n');
  return http.Response.bytes(
    utf8.encode(buffer.toString()),
    statusCode,
    headers: <String, String>{
      'content-type': 'text/event-stream; charset=utf-8',
    },
  );
}

/// 从 user 消息 content（可能为 String 或 parts 数组）中提取文本。
String _extractUserText(Map<String, dynamic> message) {
  final Object? content = message['content'];
  if (content is String) {
    return content;
  }
  if (content is List) {
    final StringBuffer buffer = StringBuffer();
    for (final Object? part in content) {
      if (part is Map<String, dynamic>) {
        final Object? type = part['type'];
        if (type == 'text') {
          buffer.write(part['text'] as String? ?? '');
        }
      }
    }
    return buffer.toString();
  }
  return '';
}

void main() {
  group('DeepSeekService performStream', () {
    test('文本模式：流式分块返回并发送正确的 payload', () async {
      late Map<String, dynamic> capturedPayload;
      late String capturedAuth;
      late Uri capturedUrl;

      final MockClient client = MockClient((http.Request request) async {
        capturedUrl = request.url;
        capturedAuth = request.headers['Authorization'] ?? '';
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return sseResponse(<String>['你好', '，', '世界']);
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      final List<String> chunks = await service
          .performStream(
            action: AiToolAction.translate,
            apiKey: 'sk-test-123',
            selectionText: 'Hello PDF',
          )
          .toList();

      expect(chunks, <String>['你好', '，', '世界']);
      expect(capturedUrl.path, '/v1/chat/completions');
      expect(capturedAuth, 'Bearer sk-test-123');
      expect(capturedPayload['model'], DeepSeekService.model);

      final List<dynamic> messages =
          capturedPayload['messages'] as List<dynamic>;
      expect(messages, hasLength(2));
      expect((messages[0] as Map<String, dynamic>)['role'], 'system');
      expect((messages[1] as Map<String, dynamic>)['role'], 'user');
      expect(
        _extractUserText(messages[1] as Map<String, dynamic>),
        contains('Hello PDF'),
      );
    });

    test('vision 模式：发送图片 data URI', () async {
      late Map<String, dynamic> capturedPayload;

      final MockClient client = MockClient((http.Request request) async {
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return sseResponse(<String>['识别结果']);
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3]);
      await service
          .performStream(
            action: AiToolAction.explain,
            apiKey: 'sk-test-123',
            selectionText: '',
            imageBytes: bytes,
          )
          .toList();

      final List<dynamic> messages =
          capturedPayload['messages'] as List<dynamic>;
      final Map<String, dynamic> userMessage =
          messages.last as Map<String, dynamic>;
      final List<dynamic> content = userMessage['content'] as List<dynamic>;
      expect(content, hasLength(2));
      expect((content[0] as Map<String, dynamic>)['type'], 'text');
      final Map<String, dynamic> image = content[1] as Map<String, dynamic>;
      expect(image['type'], 'image_url');
      expect(
        (image['image_url'] as Map<String, dynamic>)['url'],
        'data:image/png;base64,${base64Encode(bytes)}',
      );
    });

    test('缺少 API Key 时抛 DeepSeekException', () async {
      final MockClient client = MockClient((http.Request request) async {
        return sseResponse(<String>['x']);
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      expect(
        () => service
            .performStream(
              action: AiToolAction.translate,
              apiKey: '  ',
              selectionText: 'hello',
            )
            .toList(),
        throwsA(isA<DeepSeekException>()),
      );
    });

    test('API Key 无效时返回认证错误', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{'message': 'Invalid API key provided'},
          }),
          401,
        );
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      expect(
        () => service
            .performStream(
              action: AiToolAction.translate,
              apiKey: 'sk-bad',
              selectionText: 'hello',
            )
            .toList(),
        throwsA(
          isA<DeepSeekException>().having(
            (DeepSeekException e) => e.message,
            'message',
            contains('认证失败'),
          ),
        ),
      );
    });
  });

  group('DeepSeekService chatStream', () {
    test('多轮历史角色映射正确', () async {
      late Map<String, dynamic> capturedPayload;

      final MockClient client = MockClient((http.Request request) async {
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return sseResponse(<String>['回答']);
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      final List<String> chunks = await service
          .chatStream(
            apiKey: 'sk-test-123',
            history: <Map<String, String>>[
              <String, String>{'role': 'user', 'content': '你好'},
              <String, String>{'role': 'assistant', 'content': '你好，请问有什么可以帮你？'},
              <String, String>{'role': 'user', 'content': '介绍下 PDF'},
            ],
          )
          .toList();

      expect(chunks, <String>['回答']);
      final List<dynamic> messages =
          capturedPayload['messages'] as List<dynamic>;
      expect(messages, hasLength(4));
      expect((messages[0] as Map<String, dynamic>)['role'], 'system');
      expect((messages[1] as Map<String, dynamic>)['role'], 'user');
      expect((messages[2] as Map<String, dynamic>)['role'], 'assistant');
      expect((messages[3] as Map<String, dynamic>)['role'], 'user');
    });

    test('chat 聚合流式结果', () async {
      final MockClient client = MockClient((http.Request request) async {
        return sseResponse(<String>['多', '轮', '回复']);
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      final String result = await service.chat(
        apiKey: 'sk-test-123',
        history: <Map<String, String>>[
          <String, String>{'role': 'user', 'content': '你好'},
        ],
      );

      expect(result, '多轮回复');
    });
  });
}
