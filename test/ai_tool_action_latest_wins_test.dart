import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/models/ai_chat_history_message.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_context.dart';
import 'package:plume_pdf/app/modules/home/services/ai_agent_session.dart';
import 'package:plume_pdf/app/modules/home/services/deepseek_service.dart';

class _LatestWinsDeepSeekService extends DeepSeekService {
  final Completer<void> firstCancelGate = Completer<void>();
  final List<AiToolAction> startedActions = <AiToolAction>[];
  final List<List<AiChatHistoryMessage>> historySnapshots =
      <List<AiChatHistoryMessage>>[];
  final List<StreamController<DeepSeekStreamChunk>> controllers =
      <StreamController<DeepSeekStreamChunk>>[];

  @override
  Stream<DeepSeekStreamChunk> performStream({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
    Uint8List? imageBytes,
  }) {
    startedActions.add(action);
    historySnapshots.add(
      List<AiChatHistoryMessage>.of(history ?? const <AiChatHistoryMessage>[]),
    );
    final int index = controllers.length;
    final StreamController<DeepSeekStreamChunk> controller =
        StreamController<DeepSeekStreamChunk>(
          onCancel: index == 0 ? () => firstCancelGate.future : null,
        );
    controllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<DeepSeekStreamChunk> chatStream({
    required String apiKey,
    required List<AiChatHistoryMessage> history,
    PdfAiContext? documentContext,
  }) => const Stream<DeepSeekStreamChunk>.empty();

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
  test(
    'repeated tool actions cancel active/pending work and only latest request starts',
    () async {
      final _LatestWinsDeepSeekService fake = _LatestWinsDeepSeekService();
      final AiAgentSession session = AiAgentSession(deepSeekService: fake);

      final Future<AiStreamResult> first = session.runToolAction(
        action: AiToolAction.translate,
        apiKey: 'k',
        selectionText: 'first',
        onPreview: (_, _) {},
      );
      await fake.waitForCalls(1);
      fake.controllers[0].add(
        const DeepSeekStreamChunk(text: '第一轮部分回答'),
      );
      await Future<void>.delayed(Duration.zero);

      // 第二轮会停止正在运行的第一轮，并等待它完成 history 收尾。
      final Future<AiStreamResult> second = session.runToolAction(
        action: AiToolAction.explain,
        apiKey: 'k',
        selectionText: 'second',
        onPreview: (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(fake.controllers, hasLength(1));

      // 第一轮 cancel 尚未收尾时再触发第三轮：第二轮应在真正发网前被淘汰。
      final Future<AiStreamResult> third = session.runToolAction(
        action: AiToolAction.deepDive,
        apiKey: 'k',
        selectionText: 'third',
        onPreview: (_, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(fake.controllers, hasLength(1));

      fake.firstCancelGate.complete();

      final AiStreamResult firstResult = await first;
      final AiStreamResult secondResult = await second;
      expect(firstResult.stopped, isTrue);
      expect(firstResult.content, '第一轮部分回答');
      expect(secondResult.stopped, isTrue);
      expect(secondResult.content, isEmpty);

      await fake.waitForCalls(2);
      expect(
        fake.startedActions,
        <AiToolAction>[AiToolAction.translate, AiToolAction.deepDive],
        reason: '中间的 explain 必须在 transport 前被淘汰，不能堆积真实请求',
      );
      expect(fake.historySnapshots[1], hasLength(2));
      expect(fake.historySnapshots[1][1].content, '第一轮部分回答');

      fake.controllers[1].add(const DeepSeekStreamChunk(text: '最终回答'));
      await fake.controllers[1].close();
      final AiStreamResult thirdResult = await third;

      expect(thirdResult.stopped, isFalse);
      expect(thirdResult.content, '最终回答');
      expect(session.history, hasLength(4));
      expect(session.history[1].content, '第一轮部分回答');
      expect(session.history[3].content, '最终回答');

      await fake.closeAll();
    },
  );
}
