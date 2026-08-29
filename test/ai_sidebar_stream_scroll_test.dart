import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderBox, RenderObject, ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/ai_sidebar.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/chat_bubble.dart';

/// 贴底流式输出的滚动稳定性回归测试。
///
/// 普通列表 + FollowTailScrollController：跟随态下每个 chunk 更新
/// （含高度非单调的 markdown 渐进闭合）后 pixels 必须等于
/// maxScrollExtent（帧内贴底，无 post-frame 补偿）；用户阅读历史时
/// 内容增长不得移动滚动位置——这两点正是流式输出上下闪动的根因指标。
void main() {
  Future<void> pumpSidebar(WidgetTester tester, PdfAiPanelState state) async {
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

  AiSidebarController controller() =>
      Get.find<AiSidebarController>(tag: AiSidebarController.tag);

  void expectPinnedToBottom(String stage) {
    final ScrollPosition position = controller().scrollController.position;
    expect(
      controller().scrollController.hasClients,
      isTrue,
      reason: '$stage：列表应已挂载',
    );
    expect(
      position.pixels,
      position.maxScrollExtent,
      reason: '$stage：跟随态应保持贴底（pixels == maxScrollExtent）',
    );
  }

  /// 渲染层验证：最新气泡必须画在视口内。
  ///
  /// 仅断言 pixels 数值无法发现"值已修正但画面晚一帧渲染"的错误
  /// （correction 未触发同帧重排时，气泡底部会超出视口一段增量），
  /// 因此以最新气泡的渲染位置为准。容差覆盖列表 padding 与气泡
  /// margin（12 + 12）。
  void expectLatestBubbleVisible(WidgetTester tester, String stage) {
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
    final RenderBox bubbleBox = renderObject;
    final double bubbleBottom = bubbleBox
        .localToGlobal(Offset(0, bubbleBox.size.height), ancestor: viewportBox)
        .dy;
    expect(
      bubbleBottom,
      lessThanOrEqualTo(viewportBox.size.height + 24.5),
      reason: '$stage：最新内容应渲染在视口内（实际底部 $bubbleBottom，'
          '视口高 ${viewportBox.size.height}）',
    );
  }

  testWidgets('流式增量输出（含代码块渐进闭合）时滚动全程贴底', (tester) async {
    PdfAiPanelState state = const PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));
    expectPinnedToBottom('loading 占位');

    const String paragraph =
        'Transformer 模型的核心在于自注意力机制，它允许模型在处理每个词时'
        '同时关注输入序列中的所有其他词，从而捕捉长距离依赖关系。'
        '多头注意力将向量空间切分为多个子空间，各自独立计算注意力权重，'
        '再拼接回统一的表示。\n\n';

    // chunk 序列刻意包含未闭合代码块逐步补全的过程：
    // 流式中 markdown 语法从不完整到完整，渲染高度会非单调变化。
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

    final StringBuffer buffer = StringBuffer();
    bool overflowed = false;
    for (int i = 0; i < pieces.length; i++) {
      buffer.write(pieces[i]);
      state = state.copyWith(result: buffer.toString(), loading: true);
      await pumpSidebar(tester, state);
      await tester.pump(const Duration(milliseconds: 16));

      expectPinnedToBottom('chunk $i');
      expectLatestBubbleVisible(tester, 'chunk $i');
      // 增量不新增消息。
      expect(
        controller().messages,
        hasLength(2),
        reason: 'chunk $i：增量更新不应新增消息',
      );

      if (!overflowed &&
          controller().scrollController.position.maxScrollExtent > 0) {
        overflowed = true;
      }
    }
    expect(overflowed, isTrue, reason: '内容应超出视口，否则贴底断言无意义');

    // 完成：追问建议插入列表尾部，滚动位置仍应贴底。
    state = state.copyWith(
      loading: false,
      followUpSuggestions: const <String>['什么是位置编码', '对比 RNN 的差异'],
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));
    expectPinnedToBottom('完成态');
  });

  testWidgets('响应替换（非前缀更新）时滚动仍贴底', (tester) async {
    PdfAiPanelState state = const PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
      result:
          '首先是一段较长的初始回答，'
          '用于撑出超出视口的内容高度，'
          '验证替换模式下的滚动行为。',
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));

    // 非前缀变化触发 _ResultUpdateMode.replace（整条消息重建）。
    state = state.copyWith(result: '替换后的短回答。', loading: true);
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 16));
    expectPinnedToBottom('替换后');

    state = state.copyWith(
      loading: false,
      followUpSuggestions: const <String>['继续'],
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));
    expectPinnedToBottom('完成态');
  });

  const String longText =
      'Transformer 模型的核心在于自注意力机制，它允许模型在处理每个词时'
      '同时关注输入序列中的所有其他词，从而捕捉长距离依赖关系。'
      '多头注意力将向量空间切分为多个子空间，各自独立计算注意力权重，'
      '再拼接回统一的表示。\n\n';

  /// 模拟用户滚离底部：跳到距底 300px 处并用滚轮事件进入用户控制态。
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

  testWidgets('用户滚回底部阈值内时恢复跟随并贴底', (tester) async {
    PdfAiPanelState state = PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
      result: List<String>.filled(8, longText).join(),
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));

    final AiSidebarController sidebarController = controller();
    final ScrollPosition position = sidebarController.scrollController.position;
    expect(position.maxScrollExtent, greaterThan(300));

    moveAwayFromBottom(sidebarController);

    // 模拟用户向底部方向滚动并进入阈值（extentAfter <= 80）。
    sidebarController.handleScrollNotification(
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
  });

  testWidgets('流式增长时用户阅读的历史位置保持稳定', (tester) async {
    PdfAiPanelState state = PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
      result: List<String>.filled(6, longText).join(),
    );
    await pumpSidebar(tester, state);
    await tester.pump(const Duration(milliseconds: 100));

    final AiSidebarController sidebarController = controller();
    final ScrollPosition position = sidebarController.scrollController.position;
    moveAwayFromBottom(sidebarController);
    final double pixelsBefore = position.pixels;

    // 流式输出使最新气泡增高：普通列表中增长发生在滚动范围的
    // 底端之外，阅读位置的 pixels 不应移动。
    state = state.copyWith(result: List<String>.filled(12, longText).join());
    await pumpSidebar(tester, state);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(position.pixels, pixelsBefore, reason: '用户阅读历史时，流式内容增长不得移动滚动位置');
  });
}
