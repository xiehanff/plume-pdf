import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AiSidebarController createController(PdfAiPanelState state) {
    return AiSidebarController(
      state: state,
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {},
      onSendChat: (_) async {},
      onStopChat: () {},
      onNewSession: () {},
    );
  }

  void syncState(AiSidebarController controller, PdfAiPanelState state) {
    controller.updateExternalState(
      state: state,
      documentPath: null,
      leftSidebarWidth: 0,
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {},
      onSendChat: (_) async {},
      onStopChat: () {},
      onNewSession: () {},
    );
  }

  test('停止前尚无正文时移除空 loading 占位', () {
    final PdfAiPanelState loading = const PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
    );
    final AiSidebarController controller = createController(loading);
    addTearDown(controller.onClose);

    expect(controller.messages, hasLength(2));
    expect(controller.messages.last.isLoading, isTrue);

    syncState(controller, loading.copyWith(loading: false));

    expect(controller.messages, hasLength(1));
    expect(controller.messages.single.isLoading, isFalse);
  });

  test('停止后保留部分正文并结束 loading 状态', () {
    final PdfAiPanelState loading = const PdfAiPanelState(
      sessionId: 1,
      loading: true,
      actionLabel: '解释',
      actionId: 1,
      result: '已经输出的部分回答',
    );
    final AiSidebarController controller = createController(loading);
    addTearDown(controller.onClose);

    expect(controller.messages.last.text, '已经输出的部分回答');
    expect(controller.messages.last.isLoading, isTrue);

    syncState(controller, loading.copyWith(loading: false));

    expect(controller.messages.last.text, '已经输出的部分回答');
    expect(controller.messages.last.isLoading, isFalse);
  });
}
