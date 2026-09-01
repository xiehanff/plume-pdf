import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gpt_markdown/custom_widgets/custom_divider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/ai_sidebar.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/chat_bubble.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/chat_message.dart';

void main() {
  Future<void> pumpSidebar(WidgetTester tester, PdfAiPanelState state) async {
    // 模拟 HomeController：首次注册，之后通过 updateExternalState 同步新状态。
    if (!Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      Get.put(
        AiSidebarController(
          state: state,
          onApiKeyChanged: (_) {},
          onSaveApiKey: () async {},
          onSendChat: (_) async {},
          onNewSession: () {},
        ),
        tag: AiSidebarController.tag,
      );
      addTearDown(() {
        if (Get.isRegistered<AiSidebarController>(
          tag: AiSidebarController.tag,
        )) {
          Get.delete<AiSidebarController>(
            tag: AiSidebarController.tag,
            force: true,
          );
        }
      });
    }
    Get.find<AiSidebarController>(
      tag: AiSidebarController.tag,
    ).updateExternalState(
      state: state,
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {},
      onSendChat: (_) async {},
      onNewSession: () {},
      documentPath: null,
      leftSidebarWidth: 0,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiSidebar())),
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
    // reverse 布局只影响视觉顺序（index 0 在最底部）；数据层仍是
    // 用户消息在前、loading 占位在后，据此断言时序。
    final AiSidebarController controller = Get.find<AiSidebarController>(
      tag: AiSidebarController.tag,
    );
    expect(controller.messages, hasLength(2));
    final ChatMessage first = controller.messages[0];
    expect(first.author, MessageAuthor.human);
    expect(first.imageBytes, isNotNull);
    // 第二条：模型侧 loading
    final ChatMessage second = controller.messages[1];
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

  testWidgets('正文渲染不产生分割线（--- 水平线与 h1 自动线）', (tester) async {
    const PdfAiPanelState state = PdfAiPanelState(
      sessionId: 3,
      loading: false,
      actionLabel: '解释',
      actionId: 1,
      result:
          '# 概念\n\n第一段内容。\n\n---\n\n第二段内容。\n\n'
          '```yaml\n---\nname: config\n```',
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));

    // HrLine（---）与 h1 后自动分割线都渲染为 CustomDivider。
    expect(find.byType(CustomDivider), findsNothing);
    // 分割线被隐藏，正文内容保留。
    expect(find.textContaining('第一段内容'), findsOneWidget);
    expect(find.textContaining('第二段内容'), findsOneWidget);
    // 代码块内的 `---`（YAML 分隔符）不属于分割线，必须原样保留。
    // HighlightView 将代码渲染为 RichText，需要 findRichText 匹配。
    expect(
      find.textContaining('name: config', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        RegExp(r'^---$', multiLine: true),
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('推理过程折叠态纯文本轻量渲染，展开后完整 markdown 渲染', (tester) async {
    final String reasoning = List<String>.generate(
      9,
      (int index) => '推理第 ${index + 1} 行',
    ).join('\n');
    final PdfAiPanelState state = PdfAiPanelState(
      sessionId: 2,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
      reasoning: reasoning,
    );

    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ReasoningPanel), findsOneWidget);
    // 折叠态：轻量纯文本渲染（不构建完整 Markdown），八行截断 + 渐隐遮罩。
    expect(find.byType(GptMarkdown), findsNothing);
    expect(find.textContaining('推理第 1 行'), findsOneWidget);
    expect(find.text('展开全部'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.tap(find.text('展开全部'));
    await tester.pump();
    expect(find.text('收起'), findsOneWidget);
    // 展开态：完整 Markdown 渲染，解除截断与遮罩。
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
  });
}
