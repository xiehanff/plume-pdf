import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/ai_sidebar.dart';

void main() {
  testWidgets('移动端 API Key 为空不关闭，非空保存完成后关闭设置弹窗', (
    WidgetTester tester,
  ) async {
    bool saved = false;
    final AiSidebarController controller = AiSidebarController(
      state: const PdfAiPanelState(),
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {
        saved = true;
      },
      onSendChat: (_) async {},
      onNewSession: () {},
    );
    Get.put<AiSidebarController>(controller, tag: AiSidebarController.tag);
    addTearDown(() {
      if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
        Get.delete<AiSidebarController>(tag: AiSidebarController.tag, force: true);
      }
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

    // 非空时等待持久化完成，然后关闭底部弹窗，给用户明确的成功反馈。
    await tester.enterText(find.byType(TextField), '  sk-test-key  ');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(find.text('设置'), findsNothing);
  });
}
