import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/models/ai_chat_history_message.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_context.dart';
import 'package:plume_pdf/app/modules/home/services/ai_agent_session.dart';
import 'package:plume_pdf/app/modules/home/services/deepseek_service.dart';

/// 由测试手动放增量的假流服务。
class _FakeDeepSeekService extends DeepSeekService {
  final StreamController<DeepSeekStreamChunk> chunks =
      StreamController<DeepSeekStreamChunk>.broadcast();

  @override
  Stream<DeepSeekStreamChunk> performStreamWithReasoning({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    List<AiChatHistoryMessage>? history,
    Uint8List? imageBytes,
  }) => chunks.stream;

  @override
  Stream<DeepSeekStreamChunk> chatStreamWithReasoning({
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
}
