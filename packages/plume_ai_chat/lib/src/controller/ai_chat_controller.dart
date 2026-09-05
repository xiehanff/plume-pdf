import 'package:get/get.dart';

import '../core/ai_chat_session.dart';
import '../models/ai_chat_history_message.dart';
import '../models/ai_chat_input.dart';

abstract final class AiChatUpdateId {
  static const String messages = 'messages';
  static const String status = 'status';
  static const String input = 'input';
  static const String suggestions = 'suggestions';
  static const String settings = 'settings';
}

/// GetX controller for the reusable chat UI layer.
///
/// The host app owns creation/lifecycle and passes the controller to widgets.
/// The package does not require Get.put/Get.find or GetX routing.
class AiChatController extends GetxController {
  AiChatController({required AiChatSession session}) : _session = session;

  final AiChatSession _session;

  bool _isGenerating = false;
  String _streamingText = '';
  String _streamingReasoning = '';
  int _latestSendId = 0;

  bool get isGenerating => _isGenerating;
  String get streamingText => _streamingText;
  String get streamingReasoning => _streamingReasoning;
  List<AiChatHistoryMessage> get history => _session.history;

  Future<AiChatTurnResult> send({
    required String apiKey,
    required AiChatInput input,
    String? systemPrompt,
  }) async {
    if (input.isEmpty || _isGenerating) {
      return const AiChatTurnResult(content: '', reasoning: '');
    }

    final int sendId = ++_latestSendId;
    _isGenerating = true;
    _streamingText = '';
    _streamingReasoning = '';
    update(<String>[AiChatUpdateId.status, AiChatUpdateId.input]);

    try {
      final AiChatTurnResult result = await _session.send(
        apiKey: apiKey,
        userMessage: AiChatHistoryMessage.user(
          content: input.text,
          image: input.image,
        ),
        systemPrompt: systemPrompt,
        onPreview: (String text, String reasoning) {
          if (sendId != _latestSendId) {
            return;
          }
          _streamingText = text;
          _streamingReasoning = reasoning;
          update(<String>[AiChatUpdateId.messages]);
        },
      );
      if (sendId == _latestSendId) {
        _streamingText = result.content;
        _streamingReasoning = result.reasoning;
      }
      return result;
    } finally {
      // Stop 后允许调用方立即发起下一轮。旧 Future 随后完成时不能把
      // 新一轮的 generating 状态或 streaming preview 覆盖掉。
      if (sendId == _latestSendId) {
        _isGenerating = false;
        update(<String>[
          AiChatUpdateId.messages,
          AiChatUpdateId.status,
          AiChatUpdateId.input,
        ]);
      }
    }
  }

  bool stop() {
    final bool stopped = _session.stopActiveTurn();
    if (stopped) {
      _isGenerating = false;
      update(<String>[AiChatUpdateId.status, AiChatUpdateId.input]);
    }
    return stopped;
  }

  void newConversation() {
    // 让仍在异步收尾的旧 send() 失去 UI state ownership。
    _latestSendId++;
    _session.clear();
    _isGenerating = false;
    _streamingText = '';
    _streamingReasoning = '';
    update();
  }
}
