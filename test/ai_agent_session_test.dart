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
