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
  MultiStreamController<AiStreamEvent>? _controller;

  bool get hasListener => _controller != null;

  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) {
    return Stream<AiStreamEvent>.multi((MultiStreamController<AiStreamEvent> controller) {
      _controller = controller;
    });
  }

  void add(AiStreamEvent event) => _controller!.addSync(event);
}

class _FiniteBackend implements AiBackend {
  _FiniteBackend(this.events);

  final List<AiStreamEvent> events;

  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) =>
      Stream<AiStreamEvent>.fromIterable(events);
}

class _Harness {
  _Harness(AiBackend backend) {
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

  late final AiChatController chat;
  late final AiSidebarController sidebar;

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
  _Harness harness(AiBackend backend) {
    final _Harness value = _Harness(backend);
    addTearDown(value.dispose);
    return value;
  }

  Future<void> waitForTransport(
    WidgetTester tester,
    _ControlledBackend backend,
  ) async {
    for (int i = 0; i < 5 && !backend.hasListener; i++) {
      await tester.pump();
    }
    expect(
      backend.hasListener,
      isTrue,
      reason: 'AI transport subscription should be attached before test events',
    );
  }

  testWidgets('Package turn 时序：用户气泡先出现，loading 在其后', (tester) async {
    final _ControlledBackend backend = _ControlledBackend();
    final _Harness h = harness(backend);
    await h.mount(tester);

    unawaited(
      h.chat.submit(
        submission: AiChatSubmission(
          displayText: '',
          displayImageBytes: base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
            'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          ),
          userMessage: const AiChatHistoryMessage.user(content: '解释图片'),
        ),
      ),
    );
    await waitForTransport(tester, backend);

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
  });

  testWidgets('完成态显示正文和追问建议', (tester) async {
    final _FiniteBackend backend = _FiniteBackend(
      const <AiStreamEvent>[
        AiStreamEvent(
          text:
              '这是一个最基础的 C 语言示例'
              '<plume_follow_up_suggestions>["根据这段代码再举一个例子","解释它的运行过程"]</plume_follow_up_suggestions>',
        ),
      ],
    );
    final _Harness h = harness(backend);
    await h.mount(tester);

    final Future<AiChatTurnResult> future = h.chat.submit(
      submission: const AiChatSubmission(
        displayText: '解释',
        userMessage: AiChatHistoryMessage.user(content: '解释 prompt'),
      ),
    );
    await tester.runAsync(() async {
      await future;
    });
    await tester.pump();

    expect(find.text('这是一个最基础的 C 语言示例'), findsOneWidget);
    expect(find.byType(ChatBubble), findsNWidgets(2));
    expect(find.text('根据这段代码再举一个例子'), findsOneWidget);
    expect(find.text('解释它的运行过程'), findsOneWidget);
  });

  testWidgets('正文渲染不产生分割线（--- 水平线与 h1 自动线）', (tester) async {
    final _ControlledBackend backend = _ControlledBackend();
    final _Harness h = harness(backend);
    await h.mount(tester);
    const String answer =
        '# 概念\n\n第一段内容。\n\n---\n\n第二段内容。\n\n'
        '```yaml\n---\nname: config\n```';

    unawaited(
      h.chat.submit(
        submission: const AiChatSubmission(
          displayText: '解释',
          userMessage: AiChatHistoryMessage.user(content: 'prompt'),
        ),
      ),
    );
    await waitForTransport(tester, backend);
    backend.add(const AiStreamEvent(text: answer));
    await tester.pump(const Duration(milliseconds: 55));

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
    final _ControlledBackend backend = _ControlledBackend();
    final _Harness h = harness(backend);
    await h.mount(tester);
    final String reasoning = List<String>.generate(
      9,
      (int index) => '推理第 ${index + 1} 行',
    ).join('\n');

    unawaited(
      h.chat.submit(
        submission: const AiChatSubmission(
          displayText: '解释',
          userMessage: AiChatHistoryMessage.user(content: 'prompt'),
        ),
      ),
    );
    await waitForTransport(tester, backend);
    backend.add(AiStreamEvent(reasoning: reasoning));
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
  });
}
