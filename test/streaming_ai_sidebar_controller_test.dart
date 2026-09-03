import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/ai_sidebar.dart';

void main() {
  testWidgets('用户阅读历史时延迟流式 rebuild，回到底部后一次 flush', (
    WidgetTester tester,
  ) async {
    final String initialResult = List<String>.filled(
      30,
      '这是一段用于撑高 AI 回复区域的历史内容。\n\n',
    ).join();
    PdfAiPanelState state = PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
      result: initialResult,
    );

    final AiSidebarController sidebarController = AiSidebarController(
      state: state,
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {},
      onSendChat: (_) async {},
      onStopChat: () {},
      onNewSession: () {},
    );
    Get.put<AiSidebarController>(
      sidebarController,
      tag: AiSidebarController.tag,
    );
    addTearDown(() {
      if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
        Get.delete<AiSidebarController>(tag: AiSidebarController.tag, force: true);
      }
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiSidebar())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final ScrollPosition position = sidebarController.scrollController.position;
    expect(position.maxScrollExtent, greaterThan(300));

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

    const String marker = 'LATEST_STREAM_MARKER';
    state = state.copyWith(result: '$initialResult\n\n$marker');
    sidebarController.updateExternalState(
      state: state,
      documentPath: null,
      leftSidebarWidth: 0,
    );
    await tester.pump();

    expect(sidebarController.messages.last.text, contains(marker));
    expect(
      find.textContaining(marker, findRichText: true),
      findsNothing,
      reason: '用户滚离底部时，数据应继续累积，但昂贵的聊天 UI 不应重建',
    );

    sidebarController.handleScrollNotification(
      UserScrollNotification(
        direction: ScrollDirection.reverse,
        metrics: FixedScrollMetrics(
          pixels: position.maxScrollExtent - 40,
          minScrollExtent: position.minScrollExtent,
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
      find.textContaining(marker, findRichText: true),
      findsOneWidget,
      reason: '用户回到底部阈值后应一次性 flush 最新流式内容',
    );
  });
}
