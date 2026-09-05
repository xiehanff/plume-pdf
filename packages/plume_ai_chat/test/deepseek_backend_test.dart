import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';

void main() {
  test('serializes generic chat history and parses SSE deltas', () async {
    late Map<String, dynamic> requestBody;
    final MockClient client = MockClient((http.Request request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        'data: {"choices":[{"delta":{"reasoning_content":"r","content":"a"}}]}\n\n'
        'data: [DONE]\n\n',
        200,
        headers: <String, String>{'content-type': 'text/event-stream'},
      );
    });
    final DeepSeekBackend backend = DeepSeekBackend(httpClient: client);

    final List<AiStreamEvent> events = await backend
        .chat(
          const AiBackendRequest(
            apiKey: 'key',
            systemPrompt: 'system',
            history: <AiChatHistoryMessage>[
              AiChatHistoryMessage.user(content: 'hello'),
            ],
          ),
        )
        .toList();

    expect(requestBody['model'], 'deepseek-v4-flash-vision-exp');
    expect((requestBody['messages'] as List).length, 2);
    expect(events.single.text, 'a');
    expect(events.single.reasoning, 'r');
  });

  test('serializes image attachments without host-domain dependencies', () async {
    late Map<String, dynamic> requestBody;
    final MockClient client = MockClient((http.Request request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('data: [DONE]\n\n', 200);
    });
    final DeepSeekBackend backend = DeepSeekBackend(httpClient: client);

    await backend
        .chat(
          AiBackendRequest(
            apiKey: 'key',
            history: <AiChatHistoryMessage>[
              AiChatHistoryMessage.user(
                content: 'image',
                image: AiImageAttachment(
                  bytes: Uint8List.fromList(<int>[1, 2, 3]),
                  mimeType: 'image/png',
                ),
              ),
            ],
          ),
        )
        .toList();

    final List<dynamic> messages = requestBody['messages'] as List<dynamic>;
    final Map<String, dynamic> user = messages.single as Map<String, dynamic>;
    final List<dynamic> content = user['content'] as List<dynamic>;
    final Map<String, dynamic> image = content[1] as Map<String, dynamic>;
    final Map<String, dynamic> imageUrl =
        image['image_url'] as Map<String, dynamic>;
    expect(imageUrl['url'], 'data:image/png;base64,AQID');
  });
}
