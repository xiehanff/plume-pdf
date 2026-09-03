import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/models/ai_chat_history_message.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_context.dart';
import 'package:plume_pdf/app/modules/home/services/ai_agent_session.dart';
import 'package:plume_pdf/app/modules/home/services/deepseek_service.dart';

/// 由测试手动放增量的假流服务。
class _FakeDeepSeekService extends DeepSeekService {
  _FakeDeepSeekService() {
    chunks = StreamController<DeepSeekStreamChunk>.broadcast(
      onCancel: () {
        canceled = true;
      },
    );
  }

  late final StreamController<DeepSeekStreamChunk> chunks;
  bool canceled = false;

  @override
  Stream<DeepSeekStreamChunk> performStream({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
    Uint8List? imageBytes,
  }) => chunks.stream;

  @override
  Stream<DeepSeekStreamChunk> chatStream({
    required String apiKey,
    required List<AiChatHistoryMessage> history,
    PdfAiContext? documentContext,
  }) => chunks.stream;
}

/// 为每次 chat 创建独立流，并故意阻塞第一条流的 cancel。
/// 用来稳定复现“Stop 后 UI 已允许第二次发送，但旧请求仍在异步收尾”。
class _DelayedCancelDeepSeekService extends DeepSeekService {
  final Completer<void> firstCancelGate = Completer<void>();
  final List<StreamController<DeepSeekStreamChunk>> controllers =
      <StreamController<DeepSeekStreamChunk>>[];

  @override
  Stream<DeepSeekStreamChunk> chatStream({
    required String apiKey,
    required List<AiChatHistoryMessage> history,
    PdfAiContext? documentContext,
  }) {
    final int index = controllers.length;
    final StreamController<DeepSeekStreamChunk> controller =
        StreamController<DeepSeekStreamChunk>(
          onCancel: index == 0 ? () => firstCancelGate.future : null,
        );
    controllers.add(controller);
    return controller.stream;
  }

  Future<void> waitForCalls(int count) async {
    while (controllers.length < count) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> closeAll() async {
    for (final StreamController<DeepSeekStreamChunk> controller in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }
}

void main() {
  test('正常完成：写入 user/assistant 历史并返回结果', () async {
    final _FakeDeepSeekService fake = _FakeDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);

    final Future<AiStreamResult> running = session.runToolAction(
      action: AiToolAction.translate,
      apiKey: 'k',
      selectionText: 'hello',
      onPreview: (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    fake.chunks.add(const DeepSeekStreamChunk(text: '完整', reasoning: '推理'));
    await Future<void>.delayed(Duration.zero);
    fake.chunks.add(const DeepSeekStreamChunk(text: '回答'));
    await fake.chunks.close();

    final AiStreamResult result = await running;
    expect(result.content, '完整回答');
    expect(result.reasoning, '推理');
    expect(session.history, hasLength(2));
    expect(session.history.last.role, AiChatHistoryRole.assistant);
  });

  test('高频 chunk 在 40ms 窗口内合并为一次 preview', () async {
    final _FakeDeepSeekService fake = _FakeDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);
    final List<String> previews = <String>[];

    final Future<AiStreamResult> running = session.runToolAction(
      action: AiToolAction.translate,
      apiKey: 'k',
      selectionText: 'hello',
      onPreview: (String text, String reasoning) {
        previews.add(text);
      },
    );
    await Future<void>.delayed(Duration.zero);

    for (int index = 0; index < 10; index++) {
      fake.chunks.add(DeepSeekStreamChunk(text: '$index'));
    }

    await Future<void>.delayed(const Duration(milliseconds: 55));
    expect(previews, <String>['0123456789']);

    await fake.chunks.close();
    final AiStreamResult result = await running;
    expect(result.content, '0123456789');
  });

  test('流异常会取消 pending preview，错误后不再回调旧内容', () async {
    final _FakeDeepSeekService fake = _FakeDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);
    int previewCount = 0;

    final Future<AiStreamResult> running = session.runToolAction(
      action: AiToolAction.translate,
      apiKey: 'k',
      selectionText: 'hello',
      onPreview: (String text, String reasoning) {
        previewCount++;
      },
    );
    await Future<void>.delayed(Duration.zero);

    fake.chunks.add(const DeepSeekStreamChunk(text: '部分回答'));
    await Future<void>.delayed(Duration.zero);
    fake.chunks.addError(StateError('network failed'));

    await expectLater(running, throwsA(isA<StateError>()));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(previewCount, 0);

    await fake.chunks.close();
  });

  test('主动停止会取消底层 subscription 并保留已收到的部分回答', () async {
    final _FakeDeepSeekService fake = _FakeDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);

    final Future<AiStreamResult> running = session.sendChat(
      apiKey: 'k',
      userMessage: const AiChatHistoryMessage.user(content: '你好'),
      onPreview: (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);

    fake.chunks.add(const DeepSeekStreamChunk(text: '部分回答'));
    await Future<void>.delayed(Duration.zero);

    expect(session.stopActiveStream(), isTrue);
    final AiStreamResult result = await running.timeout(
      const Duration(seconds: 1),
    );

    expect(fake.canceled, isTrue);
    expect(result.stopped, isTrue);
    expect(result.content, '部分回答');
    expect(session.history, hasLength(2));
    expect(session.history.last.role, AiChatHistoryRole.assistant);
    expect(session.history.last.content, '部分回答');

    await fake.chunks.close();
  });

  test('Stop 后立即再次发送：旧 partial assistant 仍插回旧 user 后面', () async {
    final _DelayedCancelDeepSeekService fake = _DelayedCancelDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);
    const AiChatHistoryMessage user1 = AiChatHistoryMessage.user(content: '第一问');
    const AiChatHistoryMessage user2 = AiChatHistoryMessage.user(content: '第二问');

    final Future<AiStreamResult> first = session.sendChat(
      apiKey: 'k',
      userMessage: user1,
      onPreview: (_, _) {},
    );
    await fake.waitForCalls(1);
    fake.controllers[0].add(const DeepSeekStreamChunk(text: '第一问部分回答'));
    await Future<void>.delayed(Duration.zero);

    expect(session.stopActiveStream(), isTrue);

    // 不等待第一条 cancel 收尾，模拟 UI 立即恢复发送按钮后的真实操作。
    final Future<AiStreamResult> second = session.sendChat(
      apiKey: 'k',
      userMessage: user2,
      onPreview: (_, _) {},
    );
    await fake.waitForCalls(2);
    expect(
      session.history.map((AiChatHistoryMessage m) => m.content).toList(),
      <String>['第一问', '第二问'],
    );

    fake.firstCancelGate.complete();
    final AiStreamResult firstResult = await first;
    expect(firstResult.stopped, isTrue);

    expect(
      session.history.map((AiChatHistoryMessage m) => m.content).toList(),
      <String>['第一问', '第一问部分回答', '第二问'],
    );

    fake.controllers[1].add(const DeepSeekStreamChunk(text: '第二问回答'));
    await fake.controllers[1].close();
    await second;

    expect(
      session.history.map((AiChatHistoryMessage m) => m.content).toList(),
      <String>['第一问', '第一问部分回答', '第二问', '第二问回答'],
    );
    await fake.closeAll();
  });

  test('首 token 前 Stop 后立即发送：只移除旧 user，不误删新 user', () async {
    final _DelayedCancelDeepSeekService fake = _DelayedCancelDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);
    const AiChatHistoryMessage user1 = AiChatHistoryMessage.user(content: '旧问题');
    const AiChatHistoryMessage user2 = AiChatHistoryMessage.user(content: '新问题');

    final Future<AiStreamResult> first = session.sendChat(
      apiKey: 'k',
      userMessage: user1,
      onPreview: (_, _) {},
    );
    await fake.waitForCalls(1);
    expect(session.stopActiveStream(), isTrue);

    final Future<AiStreamResult> second = session.sendChat(
      apiKey: 'k',
      userMessage: user2,
      onPreview: (_, _) {},
    );
    await fake.waitForCalls(2);
    expect(session.history, <AiChatHistoryMessage>[user1, user2]);

    fake.firstCancelGate.complete();
    final AiStreamResult firstResult = await first;
    expect(firstResult.stopped, isTrue);
    expect(firstResult.content, isEmpty);
    expect(session.history, <AiChatHistoryMessage>[user2]);

    fake.controllers[1].add(const DeepSeekStreamChunk(text: '新回答'));
    await fake.controllers[1].close();
    await second;
    expect(
      session.history.map((AiChatHistoryMessage m) => m.content).toList(),
      <String>['新问题', '新回答'],
    );
    await fake.closeAll();
  });

  test('动作流式中途新建会话：旧请求完成后不写入历史', () async {
    final _FakeDeepSeekService fake = _FakeDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);

    final Future<AiStreamResult> running = session.runToolAction(
      action: AiToolAction.translate,
      apiKey: 'k',
      selectionText: 'hello',
      onPreview: (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    fake.chunks.add(const DeepSeekStreamChunk(text: '部分'));
    await Future<void>.delayed(Duration.zero);

    session.clear();

    fake.chunks.add(const DeepSeekStreamChunk(text: '回答'));
    await fake.chunks.close();
    await running;

    expect(session.history, isEmpty);
  });

  test('对话流式中途新建会话：旧请求不写入 assistant 历史', () async {
    final _FakeDeepSeekService fake = _FakeDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);

    final Future<AiStreamResult> running = session.sendChat(
      apiKey: 'k',
      userMessage: const AiChatHistoryMessage.user(content: '你好'),
      onPreview: (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    fake.chunks.add(const DeepSeekStreamChunk(text: '部分'));
    await Future<void>.delayed(Duration.zero);
    expect(session.history, hasLength(1));

    session.clear();

    fake.chunks.add(const DeepSeekStreamChunk(text: '回答'));
    await fake.chunks.close();
    await running;

    expect(session.history, isEmpty);
  });
}
