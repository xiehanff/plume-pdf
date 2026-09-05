import 'package:get/get.dart';

import '../backend/ai_backend.dart';
import '../core/ai_chat_session.dart';
import '../core/ai_response_parser.dart';
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
  List<String> _followUpSuggestions = const <String>[];
  int _latestSendId = 0;

  bool get isGenerating => _isGenerating;
  String get streamingText => _streamingText;
  String get streamingReasoning => _streamingReasoning;
  List<String> get followUpSuggestions => _followUpSuggestions;
  List<AiChatHistoryMessage> get history => _session.history;

  Future<AiChatTurnResult> send({
    required String apiKey,
    required AiChatInput input,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    bool stopPrevious = false,
    bool deferHistoryCommit = false,
  }) async {
    if (input.isEmpty || (_isGenerating && !stopPrevious)) {
      return const AiChatTurnResult(content: '', reasoning: '');
    }

    final int sendId = ++_latestSendId;
    _isGenerating = true;
    _streamingText = '';
    _streamingReasoning = '';
    _followUpSuggestions = const <String>[];
    update(<String>[
      AiChatUpdateId.status,
      AiChatUpdateId.input,
      AiChatUpdateId.suggestions,
    ]);

    try {
      final AiChatTurnResult result = await _session.send(
        apiKey: apiKey,
        userMessage: AiChatHistoryMessage.user(
          content: input.text,
          image: input.image,
        ),
        systemPrompt: systemPrompt,
        options: options,
        stopPrevious: stopPrevious,
        deferHistoryCommit: deferHistoryCommit,
        onPreview: (String text, String reasoning) {
          if (sendId != _latestSendId) {
            return;
          }
          final AiResponse response = AiResponseParser.parse(text);
          _streamingText = response.content;
          _streamingReasoning = reasoning;
          _followUpSuggestions = response.followUpSuggestions;
          update(<String>[
            AiChatUpdateId.messages,
            AiChatUpdateId.suggestions,
          ]);
        },
      );
      if (sendId == _latestSendId) {
        _streamingText = result.content;
        _streamingReasoning = result.reasoning;
        _followUpSuggestions = result.followUpSuggestions;
      }
      return result;
    } finally {
      // Stop/latest-wins allows a new turn to take UI ownership immediately.
      // An older Future finishing later must not overwrite the new turn.
      if (sendId == _latestSendId) {
        _isGenerating = false;
        update(<String>[
          AiChatUpdateId.messages,
          AiChatUpdateId.status,
          AiChatUpdateId.input,
          AiChatUpdateId.suggestions,
        ]);
      }
    }
  }

  bool stop() {
    final bool stopped = _session.stopActiveTurn();
    if (stopped) {
      _isGenerating = false;
      _followUpSuggestions = const <String>[];
      update(<String>[
        AiChatUpdateId.status,
        AiChatUpdateId.input,
        AiChatUpdateId.suggestions,
      ]);
    }
    return stopped;
  }

  void newConversation() {
    // Let still-finishing old send() Futures lose UI state ownership.
    _latestSendId++;
    _session.clear();
    _isGenerating = false;
    _streamingText = '';
    _streamingReasoning = '';
    _followUpSuggestions = const <String>[];
    update();
  }
}
