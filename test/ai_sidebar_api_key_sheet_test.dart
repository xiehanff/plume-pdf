import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/ai_sidebar.dart';

class _IdleBackend implements AiBackend {
  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) =>
      const Stream<AiStreamEvent>.empty();
}

void main() {
  testWidgets('移动端 API Key 为空不关闭，非空保存完成后关闭设置弹窗', (
    WidgetTester tester,
  ) async {
    bool saved = false;
    final AiChatController chatController = AiChatController(
      session: AiChatSession(backend: _IdleBackend()),
    );
    final AiSidebarController controller = AiSidebarController(
      state: const PdfAiPanelState(),
      chatController: chatController,
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {
        saved = true;
      },
      onSendChat: (_) async {},
      onStopChat: () {},
      onNewSession: () {},
    );
    Get.put<AiSidebarController>(controller, tag: AiSidebarController.tag);
    addTearDown(() {
      if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
        Get.delete<AiSidebarController>(tag: AiSidebarController.tag, force: true);
      }
      chatController.onClose();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiSidebar(fullWidth: true)),
      ),
    );
    await tester.pump();

    expect(find.text('首次使用需要配置 API Key'), findsOneWidget);
    await tester.tap(find.text('去配置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);

    // 空值不能被当成保存成功，弹窗必须继续保留。
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(saved, isFalse);
    expect(find.text('设置'), findsOneWidget);

    // 精确定位设置弹窗里的 DeepSeek API Key 输入框，避免页面底部聊天输入框
    // 同时存在时 `find.byType(TextField)` 命中多个元素。
    final Finder apiKeyField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '输入 DeepSeek API Key',
    );
    expect(apiKeyField, findsOneWidget);

    // 非空时等待持久化完成，然后关闭底部弹窗，给用户明确的成功反馈。
    await tester.enterText(apiKeyField, '  sk-test-key  ');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(find.text('设置'), findsNothing);
  });
}
