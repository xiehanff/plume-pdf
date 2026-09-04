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

/// 为每次请求创建独立流，并故意阻塞第一条流的 cancel。
/// 同时保存 transport 真正收到的 history snapshot，避免测试只验证最终
/// 本地列表，却漏掉下一次 HTTP 请求已经携带错误上下文的情况。
class _DelayedCancelDeepSeekService extends DeepSeekService {
  final Completer<void> firstCancelGate = Completer<void>();
  final List<StreamController<DeepSeekStreamChunk>> controllers =
      <StreamController<DeepSeekStreamChunk>>[];
  final List<List<AiChatHistoryMessage>> chatHistorySnapshots =
      <List<AiChatHistoryMessage>>[];
  final List<List<AiChatHistoryMessage>> toolHistorySnapshots =
      <List<AiChatHistoryMessage>>[];

  @override
  Stream<DeepSeekStreamChunk> chatStream({
    required String apiKey,
    required List<AiChatHistoryMessage> history,
    PdfAiContext? documentContext,
  }) {
    chatHistorySnapshots.add(List<AiChatHistoryMessage>.of(history));
    return _createStream();
  }

  @override
  Stream<DeepSeekStreamChunk> performStream({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
    Uint8List? imageBytes,
  }) {
    toolHistorySnapshots.add(
      List<AiChatHistoryMessage>.of(history ?? const <AiChatHistoryMessage>[]),
    );
    return _createStream();
  }

  Stream<DeepSeekStreamChunk> _createStream() {
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

  test('Stop 后立即再次发送：第二次 transport 等旧 partial history 收尾后才启动', () async {
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
    expect(
      fake.chatHistorySnapshots.single.map((m) => m.content).toList(),
      <String>['第一问'],
    );
    fake.controllers[0].add(const DeepSeekStreamChunk(text: '第一问部分回答'));
    await Future<void>.delayed(Duration.zero);

    expect(session.stopActiveStream(), isTrue);

    // UI 可以立即创建下一轮 Future，但 transport 不能在旧 Turn 收尾前启动。
    final Future<AiStreamResult> second = session.sendChat(
      apiKey: 'k',
      userMessage: user2,
      onPreview: (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(fake.controllers, hasLength(1));
    expect(session.history.map((m) => m.content).toList(), <String>['第一问']);

    fake.firstCancelGate.complete();
    final AiStreamResult firstResult = await first;
    expect(firstResult.stopped, isTrue);
    await fake.waitForCalls(2);

    expect(
      fake.chatHistorySnapshots[1].map((m) => m.content).toList(),
      <String>['第一问', '第一问部分回答', '第二问'],
    );

    fake.controllers[1].add(const DeepSeekStreamChunk(text: '第二问回答'));
    await fake.controllers[1].close();
    await second;

    expect(
      session.history.map((m) => m.content).toList(),
      <String>['第一问', '第一问部分回答', '第二问', '第二问回答'],
    );
    await fake.closeAll();
  });

  test('首 token 前 Stop 后立即发送：第二次 transport 不携带已回滚的旧 user', () async {
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
    await Future<void>.delayed(Duration.zero);
    expect(fake.controllers, hasLength(1));
    expect(session.history, <AiChatHistoryMessage>[user1]);

    fake.firstCancelGate.complete();
    final AiStreamResult firstResult = await first;
    expect(firstResult.stopped, isTrue);
    expect(firstResult.content, isEmpty);
    await fake.waitForCalls(2);

    expect(
      fake.chatHistorySnapshots[1].map((m) => m.content).toList(),
      <String>['新问题'],
    );
    expect(session.history, <AiChatHistoryMessage>[user2]);

    fake.controllers[1].add(const DeepSeekStreamChunk(text: '新回答'));
    await fake.controllers[1].close();
    await second;
    expect(
      session.history.map((m) => m.content).toList(),
      <String>['新问题', '新回答'],
    );
    await fake.closeAll();
  });

  test('等待旧 Turn 收尾的新请求仍可在真正发网前被停止', () async {
    final _DelayedCancelDeepSeekService fake = _DelayedCancelDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);

    final Future<AiStreamResult> first = session.sendChat(
      apiKey: 'k',
      userMessage: const AiChatHistoryMessage.user(content: '第一问'),
      onPreview: (_, _) {},
    );
    await fake.waitForCalls(1);
    fake.controllers[0].add(const DeepSeekStreamChunk(text: '第一问部分回答'));
    await Future<void>.delayed(Duration.zero);
    expect(session.stopActiveStream(), isTrue);

    final Future<AiStreamResult> second = session.sendChat(
      apiKey: 'k',
      userMessage: const AiChatHistoryMessage.user(content: '第二问'),
      onPreview: (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(session.stopActiveStream(), isTrue);

    fake.firstCancelGate.complete();
    await first;
    final AiStreamResult secondResult = await second;

    expect(secondResult.stopped, isTrue);
    expect(fake.controllers, hasLength(1), reason: '等待中的第二轮被停止后不得真正发网');
    expect(
      session.history.map((m) => m.content).toList(),
      <String>['第一问', '第一问部分回答'],
    );
    await fake.closeAll();
  });

  test('Tool Action 重叠：后一轮必须等前一轮 partial turn 入 history 后再发网', () async {
    final _DelayedCancelDeepSeekService fake = _DelayedCancelDeepSeekService();
    final AiAgentSession session = AiAgentSession(deepSeekService: fake);

    final Future<AiStreamResult> first = session.runToolAction(
      action: AiToolAction.translate,
      apiKey: 'k',
      selectionText: 'first selection',
      onPreview: (_, _) {},
    );
    await fake.waitForCalls(1);
    expect(fake.toolHistorySnapshots.single, isEmpty);
    fake.controllers[0].add(const DeepSeekStreamChunk(text: 'A 部分回答'));
    await Future<void>.delayed(Duration.zero);
    expect(session.stopActiveStream(), isTrue);

    final Future<AiStreamResult> second = session.runToolAction(
      action: AiToolAction.explain,
      apiKey: 'k',
      selectionText: 'second selection',
      onPreview: (_, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(fake.controllers, hasLength(1));

    fake.firstCancelGate.complete();
    await first;
    await fake.waitForCalls(2);

    expect(fake.toolHistorySnapshots[1], hasLength(2));
    expect(fake.toolHistorySnapshots[1][0].role, AiChatHistoryRole.user);
    expect(fake.toolHistorySnapshots[1][1].role, AiChatHistoryRole.assistant);
    expect(fake.toolHistorySnapshots[1][1].content, 'A 部分回答');

    fake.controllers[1].add(const DeepSeekStreamChunk(text: 'B 回答'));
    await fake.controllers[1].close();
    await second;

    expect(
      session.history.map((m) => m.role).toList(),
      <AiChatHistoryRole>[
        AiChatHistoryRole.user,
        AiChatHistoryRole.assistant,
        AiChatHistoryRole.user,
        AiChatHistoryRole.assistant,
      ],
    );
    expect(session.history[1].content, 'A 部分回答');
    expect(session.history[3].content, 'B 回答');
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
