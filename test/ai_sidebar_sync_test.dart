import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/ai_sidebar.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/chat_bubble.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/chat_message.dart';

void main() {
  Future<void> pumpSidebar(WidgetTester tester, PdfAiPanelState state) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiSidebar(
            state: state,
            onApiKeyChanged: (_) {},
            onSaveApiKey: () async {},
            onSendChat: (_) async {},
            onNewSession: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('runAiAction 时序：用户气泡先出现，loading 在其后', (tester) async {
    // 阶段1：提取中（loading=false，actionId 还未设置）→ 无用户气泡/loading
    await pumpSidebar(
      tester,
      const PdfAiPanelState(sessionId: 1, loading: false),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ChatBubble), findsNothing);

    // 阶段2：提取完成，一次性写入 loading+actionId+截图
    final PdfAiPanelState ready = PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
      actionSelectionImage: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    await pumpSidebar(tester, ready);
    await tester.pump(const Duration(milliseconds: 100));

    final List<ChatBubble> bubbles = tester
        .widgetList<ChatBubble>(find.byType(ChatBubble))
        .toList();
    expect(bubbles, hasLength(2));
    // 第一条：用户气泡（human，带图片）
    final ChatMessage first = bubbles[0].message;
    expect(first.author, MessageAuthor.human);
    expect(first.imageBytes, isNotNull);
    // 第二条：模型侧 loading
    final ChatMessage second = bubbles[1].message;
    expect(second.author, MessageAuthor.ai);
    expect(second.isLoading, isTrue);
  });

  testWidgets('流式：loading 被替换为增量内容，完成后显示追问建议', (tester) async {
    PdfAiPanelState state = const PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));

    // 首 chunk
    state = state.copyWith(result: '这是一个', loading: true);
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('这是一个'), findsOneWidget);

    // 增量 chunk
    state = state.copyWith(result: '这是一个最基础的 C 语言示例', loading: true);
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('这是一个最基础的 C 语言示例'), findsOneWidget);
    // 增量不新增消息
    final List<ChatBubble> bubbles = tester
        .widgetList<ChatBubble>(find.byType(ChatBubble))
        .toList();
    expect(bubbles, hasLength(2));

    // 完成
    state = state.copyWith(
      loading: false,
      followUpSuggestions: const <String>['根据这段代码再举一个例子', '解释它的运行过程'],
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('根据这段代码再举一个例子'), findsOneWidget);
    expect(find.text('解释它的运行过程'), findsOneWidget);
  });
}
