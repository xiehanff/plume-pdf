import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plume_pdf/app/modules/home/services/deepseek_service.dart';

void main() {
  test('400 invalid image error preserves capability details for text fallback', () async {
    // `invalid` 属于请求错误描述，不能据此把图片能力拒绝误判为认证失败。
    final MockClient client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'error': <String, dynamic>{
            'type': 'invalid_request_error',
            'message': 'Invalid image input for this model',
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
      expect(error.message, isNot(contains('认证失败')));
      expect(error.message.toLowerCase(), contains('image'));
      expect(error.canFallbackToText, isTrue);
    }
  });
}
