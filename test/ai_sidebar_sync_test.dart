import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:gpt_markdown/custom_widgets/custom_divider.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/ai_sidebar.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/chat_bubble.dart';

class _ControlledBackend implements AiBackend {
  final StreamController<AiStreamEvent> stream =
      StreamController<AiStreamEvent>();

  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) => stream.stream;
}

class _Harness {
  _Harness()
    : backend = _ControlledBackend(),
      chat = AiChatController(
        session: AiChatSession(backend: _ControlledBackend()),
      ) {
    // Replace the temporary initializer with one shared backend/controller pair.
    chat.onClose();
    chat = AiChatController(session: AiChatSession(backend: backend));
    sidebar = AiSidebarController(
      state: const PdfAiPanelState(apiKey: 'test-key'),
      chatController: chat,
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {},
      onSendChat: (_) async {},
      onStopChat: chat.stop,
      onNewSession: chat.newConversation,
    );
  }

  final _ControlledBackend backend;
  late AiChatController chat;
  late AiSidebarController sidebar;

  Future<void> mount(WidgetTester tester) async {
    Get.put<AiSidebarController>(sidebar, tag: AiSidebarController.tag);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiSidebar())),
    );
    await tester.pump();
  }

  void dispose() {
    if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      Get.delete<AiSidebarController>(tag: AiSidebarController.tag, force: true);
    }
    chat.onClose();
  }
}

void main() {
  _Harness harness(WidgetTester tester) {
    final _Harness value = _Harness();
    addTearDown(value.dispose);
    return value;
  }

  testWidgets('Package turn 时序：用户气泡先出现，loading 在其后', (tester) async {
    final _Harness h = harness(tester);
    await h.mount(tester);

    final Future<AiChatTurnResult> future = h.chat.submit(
      submission: AiChatSubmission(
        displayText: '',
        displayImageBytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
          'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
        userMessage: const AiChatHistoryMessage.user(content: '解释图片'),
      ),
    );
    await tester.pump();

    final List<ChatBubble> bubbles = tester
        .widgetList<ChatBubble>(find.byType(ChatBubble))
        .toList();
    expect(bubbles, hasLength(2));
    expect(h.sidebar.messages, hasLength(2));
    final ChatMessage first = h.sidebar.messages[0];
    expect(first.author, MessageAuthor.human);
    expect(first.imageBytes, isNotNull);
    final ChatMessage second = h.sidebar.messages[1];
    expect(second.author, MessageAuthor.ai);
    expect(second.isLoading, isTrue);

    h.chat.stop();
    await future;
  });

  testWidgets('流式：loading 被替换为增量内容，完成后显示追问建议', (tester) async {
    final _Harness h = harness(tester);
    await h.mount(tester);

    final Future<AiChatTurnResult> future = h.chat.submit(
      submission: const AiChatSubmission(
        displayText: '解释',
        userMessage: AiChatHistoryMessage.user(content: '解释 prompt'),
      ),
    );
    await tester.pump();

    h.backend.stream.add(const AiStreamEvent(text: '这是一个'));
    await tester.pump(const Duration(milliseconds: 55));
    expect(find.text('这是一个'), findsOneWidget);

    h.backend.stream.add(const AiStreamEvent(text: '最基础的 C 语言示例'));
    await tester.pump(const Duration(milliseconds: 55));
    expect(find.text('这是一个最基础的 C 语言示例'), findsOneWidget);
    expect(find.byType(ChatBubble), findsNWidgets(2));

    h.backend.stream.add(
      const AiStreamEvent(
        text:
            '<plume_follow_up_suggestions>["根据这段代码再举一个例子","解释它的运行过程"]</plume_follow_up_suggestions>',
      ),
    );
    await h.backend.stream.close();
    await future;
    await tester.pump();

    expect(find.text('根据这段代码再举一个例子'), findsOneWidget);
    expect(find.text('解释它的运行过程'), findsOneWidget);
  });

  testWidgets('正文渲染不产生分割线（--- 水平线与 h1 自动线）', (tester) async {
    final _Harness h = harness(tester);
    await h.mount(tester);
    const String answer =
        '# 概念\n\n第一段内容。\n\n---\n\n第二段内容。\n\n'
        '```yaml\n---\nname: config\n```';

    final Future<AiChatTurnResult> future = h.chat.submit(
      submission: const AiChatSubmission(
        displayText: '解释',
        userMessage: AiChatHistoryMessage.user(content: 'prompt'),
      ),
    );
    await tester.pump();
    h.backend.stream.add(const AiStreamEvent(text: answer));
    await h.backend.stream.close();
    await future;
    await tester.pump();

    expect(find.byType(CustomDivider), findsNothing);
    expect(find.textContaining('第一段内容'), findsOneWidget);
    expect(find.textContaining('第二段内容'), findsOneWidget);
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
    final _Harness h = harness(tester);
    await h.mount(tester);
    final String reasoning = List<String>.generate(
      9,
      (int index) => '推理第 ${index + 1} 行',
    ).join('\n');

    final Future<AiChatTurnResult> future = h.chat.submit(
      submission: const AiChatSubmission(
        displayText: '解释',
        userMessage: AiChatHistoryMessage.user(content: 'prompt'),
      ),
    );
    await tester.pump();
    h.backend.stream.add(AiStreamEvent(reasoning: reasoning));
    await tester.pump(const Duration(milliseconds: 55));

    expect(find.byType(ReasoningPanel), findsOneWidget);
    expect(find.byType(GptMarkdown), findsNothing);
    expect(find.textContaining('推理第 1 行'), findsOneWidget);
    expect(find.text('展开全部'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);

    await tester.tap(find.text('展开全部'));
    await tester.pump();
    expect(find.text('收起'), findsOneWidget);
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);

    h.chat.stop();
    await future;
  });
}
