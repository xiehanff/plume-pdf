import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';
import 'package:plume_pdf/app/modules/home/controllers/ai_sidebar_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_panel_state.dart';

class _ControlledBackend implements AiBackend {
  final StreamController<AiStreamEvent> stream =
      StreamController<AiStreamEvent>();
  bool started = false;

  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) {
    started = true;
    return stream.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ({
    AiChatController chat,
    AiSidebarController sidebar,
    _ControlledBackend backend,
  }) createControllers() {
    final _ControlledBackend backend = _ControlledBackend();
    final AiChatController chat = AiChatController(
      session: AiChatSession(backend: backend),
    );
    final AiSidebarController sidebar = AiSidebarController(
      state: const PdfAiPanelState(apiKey: 'test-key'),
      chatController: chat,
      onApiKeyChanged: (_) {},
      onSaveApiKey: () async {},
      onSendChat: (_) async {},
      onStopChat: chat.stop,
      onNewSession: chat.newConversation,
    );
    addTearDown(() {
      sidebar.onClose();
      chat.onClose();
    });
    return (chat: chat, sidebar: sidebar, backend: backend);
  }

  test('停止前尚无正文时移除空 loading 占位', () async {
    final controllers = createControllers();
    final Future<AiChatTurnResult> future = controllers.chat.submit(
      submission: const AiChatSubmission(
        displayText: '解释',
        userMessage: AiChatHistoryMessage.user(content: 'tool prompt'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controllers.backend.started, isTrue);
    expect(controllers.sidebar.messages, hasLength(2));
    expect(controllers.sidebar.messages.last.isLoading, isTrue);

    expect(controllers.chat.stop(), isTrue);
    await future;

    expect(controllers.sidebar.messages, hasLength(1));
    expect(controllers.sidebar.messages.single.text, '解释');
    expect(controllers.sidebar.messages.single.isLoading, isFalse);
  });

  test('停止后保留部分正文并结束 loading 状态', () async {
    final controllers = createControllers();
    final Future<AiChatTurnResult> future = controllers.chat.submit(
      submission: const AiChatSubmission(
        displayText: '解释',
        userMessage: AiChatHistoryMessage.user(content: 'tool prompt'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    controllers.backend.stream.add(
      const AiStreamEvent(text: '已经输出的部分回答'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 55));

    expect(controllers.sidebar.messages.last.text, '已经输出的部分回答');
    expect(controllers.sidebar.messages.last.isLoading, isTrue);

    expect(controllers.chat.stop(), isTrue);
    await future;

    expect(controllers.sidebar.messages.last.text, '已经输出的部分回答');
    expect(controllers.sidebar.messages.last.isLoading, isFalse);
  });
}
