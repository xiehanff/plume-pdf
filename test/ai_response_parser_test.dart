import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/services/ai_response_parser.dart';

void main() {
  test('拆分 AI 正文和上下文相关的追问建议', () {
    final AiResponse response = AiResponseParser.parse(
      '这是回答正文。\n\n'
      '${AiResponseParser.suggestionsStartTag}\n'
      '["解释这个结论的依据", "结合页面内容举例"]\n'
      '${AiResponseParser.suggestionsEndTag}',
    );

    expect(response.content, '这是回答正文。');
    expect(response.followUpSuggestions, <String>['解释这个结论的依据', '结合页面内容举例']);
  });

  test('流式响应尚未结束时不把协议标记显示到正文', () {
    final AiResponse response = AiResponseParser.parse(
      '这是回答正文。\n${AiResponseParser.suggestionsStartTag}\n["解释',
    );

    expect(response.content, '这是回答正文。');
    expect(response.followUpSuggestions, isEmpty);
  });

  test('兼容模型返回 Markdown 列表格式的建议', () {
    final AiResponse response = AiResponseParser.parse(
      '${AiResponseParser.suggestionsStartTag}\n'
      '- 继续解释这个概念\n'
      '- 给一个反例\n'
      '${AiResponseParser.suggestionsEndTag}',
    );

    expect(response.content, isEmpty);
    expect(response.followUpSuggestions, <String>['继续解释这个概念', '给一个反例']);
  });
}
