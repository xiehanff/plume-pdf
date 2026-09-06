import 'dart:async';

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';
import 'package:plume_pdf/app/modules/pdf_ai/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/pdf_ai/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/pdf_ai/views/widgets/ai_sidebar.dart';

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

void main() {
  testWidgets('用户阅读历史时延迟流式 rebuild，回到底部后一次 flush', (
    WidgetTester tester,
  ) async {
    final String initialResult = List<String>.filled(
      30,
      '这是一段用于撑高 AI 回复区域的历史内容。\n\n',
    ).join();
    final _ControlledBackend backend = _ControlledBackend();
    final AiChatController chatController = AiChatController(
      session: AiChatSession(backend: backend),
    );
    final AiSidebarController sidebarController = AiSidebarController(
      state: const PdfAiPanelState(apiKey: 'test-key'),
      chatController: chatController,
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {},
      onSendChat: (_) async {},
      onStopChat: chatController.stop,
      onNewSession: chatController.newConversation,
    );
    Get.put<AiSidebarController>(
      sidebarController,
      tag: AiSidebarController.tag,
    );
    addTearDown(() {
      if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
        Get.delete<AiSidebarController>(tag: AiSidebarController.tag, force: true);
      }
      chatController.onClose();
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiSidebar())),
    );
    await tester.pump();

    unawaited(
      chatController.submit(
        submission: const AiChatSubmission(
          displayText: '解释',
          userMessage: AiChatHistoryMessage.user(content: 'prompt'),
        ),
      ),
    );
    for (int i = 0; i < 5 && !backend.hasListener; i++) {
      await tester.pump();
    }
    expect(
      backend.hasListener,
      isTrue,
      reason: 'AI transport subscription should be attached before test events',
    );

    backend.add(AiStreamEvent(text: initialResult));
    await tester.pump(const Duration(milliseconds: 55));

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
    backend.add(const AiStreamEvent(text: '\n\n$marker'));
    await tester.pump(const Duration(milliseconds: 55));

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
