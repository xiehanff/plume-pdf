import 'dart:async';

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderBox, RenderObject, ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/ai_sidebar.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/chat_bubble.dart';

class _ControlledBackend implements AiBackend {
  final StreamController<AiStreamEvent> stream =
      StreamController<AiStreamEvent>(sync: true);

  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) => stream.stream;
}

class _Harness {
  _Harness() {
    backend = _ControlledBackend();
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

  late final _ControlledBackend backend;
  late final AiChatController chat;
  late final AiSidebarController sidebar;

  Future<void> mount(WidgetTester tester) async {
    Get.put<AiSidebarController>(sidebar, tag: AiSidebarController.tag);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiSidebar())),
    );
    await tester.pump();
  }

  Future<AiChatTurnResult> startTurn() {
    return chat.submit(
      submission: const AiChatSubmission(
        displayText: '解释',
        userMessage: AiChatHistoryMessage.user(content: 'prompt'),
      ),
    );
  }

  Future<void> waitForTransport(WidgetTester tester) async {
    for (int i = 0; i < 5 && !backend.stream.hasListener; i++) {
      await tester.pump();
    }
    expect(
      backend.stream.hasListener,
      isTrue,
      reason: 'AI transport subscription should be attached before test events',
    );
  }

  Future<void> finishTurn(
    WidgetTester tester,
    Future<AiChatTurnResult> future,
  ) async {
    final Future<void> closeFuture = backend.stream.close();
    await tester.pump();
    await closeFuture;
    await future;
    await tester.pump();
  }

  void dispose() {
    if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      Get.delete<AiSidebarController>(tag: AiSidebarController.tag, force: true);
    }
    chat.onClose();
  }
}

/// 贴底流式输出的滚动稳定性回归测试。
///
/// 真实数据源现在是 Package `AiChatController`：跟随态下 SSE preview 更新
/// 后 pixels 必须等于 maxScrollExtent；用户阅读历史时 Sidebar 会暂缓 markdown
/// rebuild，因此内容增长也不能移动当前阅读位置。
void main() {
  _Harness createHarness() {
    final _Harness h = _Harness();
    addTearDown(h.dispose);
    return h;
  }

  void expectPinnedToBottom(_Harness h, String stage) {
    final ScrollPosition position = h.sidebar.scrollController.position;
    expect(
      h.sidebar.scrollController.hasClients,
      isTrue,
      reason: '$stage：列表应已挂载',
    );
    expect(
      position.pixels,
      position.maxScrollExtent,
      reason: '$stage：跟随态应保持贴底（pixels == maxScrollExtent）',
    );
  }

  void expectLatestBubbleVisible(
    WidgetTester tester,
    String stage,
  ) {
    final RenderBox viewportBox = tester.renderObject<RenderBox>(
      find.byType(ListView),
    );
    final List<Element> bubbles = find.byType(ChatBubble).evaluate().toList();
    if (bubbles.isEmpty) {
      return;
    }
    final RenderObject? renderObject = bubbles.last.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }
    final double bubbleBottom = renderObject
        .localToGlobal(
          Offset(0, renderObject.size.height),
          ancestor: viewportBox,
        )
        .dy;
    expect(
      bubbleBottom,
      lessThanOrEqualTo(viewportBox.size.height + 24.5),
      reason: '$stage：最新内容应渲染在视口内（实际底部 $bubbleBottom，'
          '视口高 ${viewportBox.size.height}）',
    );
  }

  const String longText =
      'Transformer 模型的核心在于自注意力机制，它允许模型在处理每个词时'
      '同时关注输入序列中的所有其他词，从而捕捉长距离依赖关系。'
      '多头注意力将向量空间切分为多个子空间，各自独立计算注意力权重，'
      '再拼接回统一的表示。\n\n';

  void moveAwayFromBottom(AiSidebarController sidebarController) {
    final ScrollPosition position = sidebarController.scrollController.position;
    sidebarController.scrollController.jumpTo(
      (position.maxScrollExtent - 300).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    sidebarController.handlePointerSignal(
      const PointerScrollEvent(
        timeStamp: Duration.zero,
        scrollDelta: Offset(0, -120),
      ),
    );
  }

  testWidgets('真实流式增量（含代码块渐进闭合）时滚动全程贴底', (tester) async {
    final _Harness h = createHarness();
    await h.mount(tester);
    final Future<AiChatTurnResult> future = h.startTurn();
    await h.waitForTransport(tester);
    expectPinnedToBottom(h, 'loading 占位');

    const String paragraph = longText;
    final List<String> pieces = <String>[
      for (int i = 0; i < 5; i++) paragraph,
      '示例代码：\n\n```dart\n',
      'final Stream<String> chunks = service.chatStream();\n',
      'await for (final String chunk in chunks) {\n',
      '  buffer.write(chunk);\n',
      '}\n',
      '```\n\n',
      '- 自注意力：全序列关联\n',
      '- 多头：子空间并行\n',
      paragraph,
      paragraph,
    ];

    bool overflowed = false;
    for (int i = 0; i < pieces.length; i++) {
      h.backend.stream.add(AiStreamEvent(text: pieces[i]));
      await tester.pump(const Duration(milliseconds: 55));

      expectPinnedToBottom(h, 'chunk $i');
      expectLatestBubbleVisible(tester, 'chunk $i');
      expect(
        h.sidebar.messages,
        hasLength(2),
        reason: 'chunk $i：增量更新不应新增消息',
      );
      if (!overflowed &&
          h.sidebar.scrollController.position.maxScrollExtent > 0) {
        overflowed = true;
      }
    }
    expect(overflowed, isTrue, reason: '内容应超出视口，否则贴底断言无意义');

    h.backend.stream.add(
      const AiStreamEvent(
        text:
            '<plume_follow_up_suggestions>["什么是位置编码","对比 RNN 的差异"]</plume_follow_up_suggestions>',
      ),
    );
    await h.finishTurn(tester, future);
    expectPinnedToBottom(h, '完成态');
  });

  testWidgets('用户滚回底部阈值内时恢复跟随并刷新被延迟的流式内容', (tester) async {
    final _Harness h = createHarness();
    await h.mount(tester);
    final Future<AiChatTurnResult> future = h.startTurn();
    await h.waitForTransport(tester);

    h.backend.stream.add(
      AiStreamEvent(text: List<String>.filled(8, longText).join()),
    );
    await tester.pump(const Duration(milliseconds: 55));

    final ScrollPosition position = h.sidebar.scrollController.position;
    expect(position.maxScrollExtent, greaterThan(300));
    moveAwayFromBottom(h.sidebar);

    h.backend.stream.add(const AiStreamEvent(text: '底部新增但暂不打扰历史阅读。'));
    await tester.pump(const Duration(milliseconds: 55));

    h.sidebar.handleScrollNotification(
      UserScrollNotification(
        direction: ScrollDirection.reverse,
        metrics: FixedScrollMetrics(
          pixels: position.maxScrollExtent - 40,
          minScrollExtent: 0,
          maxScrollExtent: position.maxScrollExtent,
          viewportDimension: position.viewportDimension,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 3,
        ),
        context: tester.element(find.byType(ListView)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      position.pixels,
      position.maxScrollExtent,
      reason: '恢复跟随后应贴底，否则后续流式输出不可见',
    );

    await h.finishTurn(tester, future);
  });

  testWidgets('流式增长时用户阅读的历史位置保持稳定', (tester) async {
    final _Harness h = createHarness();
    await h.mount(tester);
    final Future<AiChatTurnResult> future = h.startTurn();
    await h.waitForTransport(tester);

    h.backend.stream.add(
      AiStreamEvent(text: List<String>.filled(6, longText).join()),
    );
    await tester.pump(const Duration(milliseconds: 55));

    final ScrollPosition position = h.sidebar.scrollController.position;
    moveAwayFromBottom(h.sidebar);
    final double pixelsBefore = position.pixels;

    h.backend.stream.add(
      AiStreamEvent(text: List<String>.filled(6, longText).join()),
    );
    await tester.pump(const Duration(milliseconds: 55));

    expect(
      position.pixels,
      pixelsBefore,
      reason: '用户阅读历史时，流式内容增长不得移动滚动位置',
    );

    await h.finishTurn(tester, future);
  });
}
