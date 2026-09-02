import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plume_pdf/app/modules/home/models/ai_chat_history_message.dart';
import 'package:plume_pdf/app/modules/home/models/ai_chat_input.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_context.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_outline_entry.dart';
import 'package:plume_pdf/app/modules/home/services/deepseek_service.dart';

http.Response sseResponse(
  List<String> chunks, {
  int statusCode = 200,
  List<String>? reasoningChunks,
}) {
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < chunks.length; index++) {
    final Map<String, String> delta = <String, String>{
      'content': chunks[index],
    };
    if (reasoningChunks != null && index < reasoningChunks.length) {
      delta['reasoning_content'] = reasoningChunks[index];
    }
    buffer
      ..write('data: ')
      ..write(
        jsonEncode(<String, dynamic>{
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{'delta': delta},
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

String _extractUserText(Map<String, dynamic> message) {
  final Object? content = message['content'];
  if (content is String) {
    return content;
  }
  if (content is List) {
    final StringBuffer buffer = StringBuffer();
    for (final Object? part in content) {
      if (part is Map<String, dynamic> && part['type'] == 'text') {
        buffer.write(part['text'] as String? ?? '');
      }
    }
    return buffer.toString();
  }
  return '';
}

void main() {
  group('DeepSeekService performStream', () {
    test('文本模式：单一 SSE 通道返回正文并发送正确 payload', () async {
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
      final List<DeepSeekStreamChunk> chunks = await service
          .performStream(
            action: AiToolAction.translate,
            apiKey: 'sk-test-123',
            selectionText: 'Hello PDF',
          )
          .toList();

      expect(
        chunks.map((DeepSeekStreamChunk chunk) => chunk.text),
        <String>['你好', '，', '世界'],
      );
      expect(capturedUrl.path, '/v1/chat/completions');
      expect(capturedAuth, 'Bearer sk-test-123');
      expect(capturedPayload['model'], DeepSeekService.model);
      expect(capturedPayload['stream'], isTrue);
      expect(capturedPayload['reasoning_effort'], 'low');

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

    test('流式同时保留 reasoning_content 和正文', () async {
      final MockClient client = MockClient((http.Request request) async {
        return sseResponse(
          <String>['正文第一段', '正文第二段'],
          reasoningChunks: <String>['先分析', '再回答'],
        );
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      final List<DeepSeekStreamChunk> chunks = await service
          .performStream(
            action: AiToolAction.explain,
            apiKey: 'sk-test-123',
            selectionText: '状态机',
          )
          .toList();

      expect(
        chunks.map((DeepSeekStreamChunk chunk) => chunk.text),
        <String>['正文第一段', '正文第二段'],
      );
      expect(
        chunks.map((DeepSeekStreamChunk chunk) => chunk.reasoning),
        <String>['先分析', '再回答'],
      );
    });

    test('vision 模式：直接构造 OpenAI image_url data URI', () async {
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
      expect((content.first as Map<String, dynamic>)['type'], 'text');
      final Map<String, dynamic> image = content.last as Map<String, dynamic>;
      expect(image['type'], 'image_url');
      expect(
        (image['image_url'] as Map<String, dynamic>)['url'],
        'data:image/png;base64,${base64Encode(bytes)}',
      );
    });

    test('深度理解保留 32768 max_tokens 且不降低 reasoning effort', () async {
      late Map<String, dynamic> capturedPayload;
      final MockClient client = MockClient((http.Request request) async {
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return sseResponse(<String>['深入回答']);
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      await service
          .performStream(
            action: AiToolAction.deepDive,
            apiKey: 'sk-test-123',
            selectionText: '解释状态机',
          )
          .toList();

      expect(capturedPayload['max_tokens'], 32768);
      expect(capturedPayload.containsKey('reasoning_effort'), isFalse);
    });

    test('缺少 API Key 时抛 DeepSeekException', () async {
      final DeepSeekService service = DeepSeekService(
        httpClient: MockClient((_) async => sseResponse(<String>['x'])),
      );
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

    test('401 认证错误不可触发 vision 文本重试', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{'message': 'Invalid API key provided'},
          }),
          401,
        );
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      try {
        await service
            .performStream(
              action: AiToolAction.translate,
              apiKey: 'sk-bad',
              selectionText: 'hello',
            )
            .toList();
        fail('expected DeepSeekException');
      } on DeepSeekException catch (error) {
        expect(error.message, contains('认证失败'));
        expect(error.statusCode, 401);
        expect(error.canFallbackToText, isFalse);
      }
    });

    test('400 图片能力拒绝允许回退文本', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{
              'message': 'This model does not support image input',
            },
          }),
          400,
        );
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      try {
        await service
            .performStream(
              action: AiToolAction.explain,
              apiKey: 'sk-test',
              selectionText: '',
              imageBytes: Uint8List.fromList(<int>[1]),
            )
            .toList();
        fail('expected DeepSeekException');
      } on DeepSeekException catch (error) {
        expect(error.statusCode, 400);
        expect(error.canFallbackToText, isTrue);
      }
    });
  });

  group('DeepSeekService chatStream', () {
    test('多轮历史角色映射正确且对话使用 low reasoning effort', () async {
      late Map<String, dynamic> capturedPayload;
      final MockClient client = MockClient((http.Request request) async {
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return sseResponse(<String>['回答']);
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      final List<DeepSeekStreamChunk> chunks = await service
          .chatStream(
            apiKey: 'sk-test-123',
            history: <AiChatHistoryMessage>[
              const AiChatHistoryMessage.user(content: '你好'),
              const AiChatHistoryMessage.assistant(content: '你好，有什么可以帮你？'),
              const AiChatHistoryMessage.user(content: '介绍下 PDF'),
            ],
          )
          .toList();

      expect(chunks.single.text, '回答');
      expect(capturedPayload['reasoning_effort'], 'low');
      final List<dynamic> messages =
          capturedPayload['messages'] as List<dynamic>;
      expect(messages, hasLength(4));
      expect((messages[0] as Map<String, dynamic>)['role'], 'system');
      expect((messages[1] as Map<String, dynamic>)['role'], 'user');
      expect((messages[2] as Map<String, dynamic>)['role'], 'assistant');
      expect((messages[3] as Map<String, dynamic>)['role'], 'user');
    });

    test('发送对话时将 PDF 上下文注入 system prompt', () async {
      late Map<String, dynamic> capturedPayload;
      final MockClient client = MockClient((http.Request request) async {
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return sseResponse(<String>['回答']);
      });

      const PdfAiContext context = PdfAiContext(
        title: 'book.pdf',
        currentPage: 3,
        pageCount: 10,
        outline: <PdfOutlineEntry>[],
        currentPageText: '当前页内容',
        requestedPage: 8,
        requestedPageText: '第八页内容',
      );
      final DeepSeekService service = DeepSeekService(httpClient: client);
      await service
          .chatStream(
            apiKey: 'sk-test-123',
            history: <AiChatHistoryMessage>[
              const AiChatHistoryMessage.user(content: '请总结'),
            ],
            documentContext: context,
          )
          .toList();

      final List<dynamic> messages =
          capturedPayload['messages'] as List<dynamic>;
      final String systemPrompt =
          (messages.first as Map<String, dynamic>)['content'] as String;
      expect(systemPrompt, contains('标题：book.pdf'));
      expect(systemPrompt, contains('当前页内容'));
      expect(systemPrompt, contains('第八页内容'));
      expect(systemPrompt, contains('<document_context>'));
      expect(systemPrompt, contains('不可信内容'));
      expect(systemPrompt, isNot(contains('文件目录')));
    });

    test('后续对话继续发送历史图片并保留 MIME 类型', () async {
      late Map<String, dynamic> capturedPayload;
      final Uint8List imageBytes = Uint8List.fromList(<int>[1, 2, 3]);
      final MockClient client = MockClient((http.Request request) async {
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return sseResponse(<String>['回答']);
      });

      final DeepSeekService service = DeepSeekService(httpClient: client);
      await service
          .chatStream(
            apiKey: 'sk-test-123',
            history: <AiChatHistoryMessage>[
              AiChatHistoryMessage.user(
                content: '请分析这张图片。',
                image: AiImageAttachment(
                  bytes: imageBytes,
                  mimeType: 'image/png',
                ),
              ),
              const AiChatHistoryMessage.assistant(content: '图片中是一张表格。'),
              const AiChatHistoryMessage.user(content: '第二列是什么意思？'),
            ],
          )
          .toList();

      final List<dynamic> messages =
          capturedPayload['messages'] as List<dynamic>;
      final Map<String, dynamic> imageMessage =
          messages[1] as Map<String, dynamic>;
      final List<dynamic> content = imageMessage['content'] as List<dynamic>;
      expect(content, hasLength(2));
      expect((content.first as Map<String, dynamic>)['type'], 'text');
      expect((content.last as Map<String, dynamic>)['type'], 'image_url');
      expect(
        ((content.last as Map<String, dynamic>)['image_url']
            as Map<String, dynamic>)['url'],
        'data:image/png;base64,${base64Encode(imageBytes)}',
      );
      expect((messages.last as Map<String, dynamic>)['content'], '第二列是什么意思？');
    });
  });
}
