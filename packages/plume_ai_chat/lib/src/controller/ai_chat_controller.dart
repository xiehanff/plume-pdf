import 'package:get/get.dart';

import '../backend/ai_backend.dart';
import '../core/ai_chat_session.dart';
import '../core/ai_response_parser.dart';
import '../models/ai_chat_history_message.dart';
import '../models/ai_chat_input.dart';
import '../models/ai_chat_submission.dart';
import '../models/chat_message.dart';
import 'ai_conversation_presenter.dart';

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
  AiChatController({
    required AiChatSession session,
    AiConversationPresenter? presenter,
  }) : _session = session,
       _presenter = presenter ?? AiConversationPresenter();

  final AiChatSession _session;
  final AiConversationPresenter _presenter;

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
  List<ChatMessage> get messages => _presenter.messages;

  /// Convenience API for a normal user chat message, where UI presentation and
  /// transport history are the same message.
  Future<AiChatTurnResult> send({
    required String apiKey,
    required AiChatInput input,
    String? systemPrompt,
    AiRequestOptions options = const AiRequestOptions(),
    bool stopPrevious = false,
    bool deferHistoryCommit = false,
  }) {
    if (input.isEmpty) {
      return Future<AiChatTurnResult>.value(
        const AiChatTurnResult(content: '', reasoning: ''),
      );
    }

    final String displayText = input.text.trim().isEmpty && input.image != null
        ? '请分析这张图片。'
        : input.text.trim();
    return submit(
      apiKey: apiKey,
      submission: AiChatSubmission(
        userMessage: AiChatHistoryMessage.user(
          content: displayText,
          image: input.image,
        ),
        displayText: displayText,
        displayImageBytes: input.image?.bytes,
        systemPrompt: systemPrompt,
        options: options,
        stopPrevious: stopPrevious,
        deferHistoryCommit: deferHistoryCommit,
      ),
    );
  }

  /// Executes a generic chat turn whose transport prompt may differ from the
  /// text/image presented in the conversation UI.
  ///
  /// This is the reusable integration point for domain actions such as PDF
  /// translate/explain, code review, email summarization, and similar workflows.
  Future<AiChatTurnResult> submit({
    required String apiKey,
    required AiChatSubmission submission,
  }) async {
    if (_isGenerating && !submission.stopPrevious) {
      return const AiChatTurnResult(content: '', reasoning: '');
    }

    final int sendId = ++_latestSendId;
    _presenter
      ..addUserMessage(
        text: submission.displayText,
        imageBytes: submission.displayImageBytes,
      )
      ..ensureLoadingPlaceholder();

    _isGenerating = true;
    _streamingText = '';
    _streamingReasoning = '';
    _followUpSuggestions = const <String>[];
    update(<String>[
      AiChatUpdateId.messages,
      AiChatUpdateId.status,
      AiChatUpdateId.input,
      AiChatUpdateId.suggestions,
    ]);

    try {
      final AiChatTurnResult result = await _session.send(
        apiKey: apiKey,
        userMessage: submission.userMessage,
        systemPrompt: submission.systemPrompt,
        options: submission.options,
        stopPrevious: submission.stopPrevious,
        deferHistoryCommit: submission.deferHistoryCommit,
        onPreview: (String text, String reasoning) {
          if (sendId != _latestSendId) {
            return;
          }
          final AiResponse response = AiResponseParser.parse(text);
          _streamingText = response.content;
          _streamingReasoning = reasoning;
          _followUpSuggestions = response.followUpSuggestions;
          _presenter.syncResponse(
            loading: true,
            result: response.content,
            reasoning: reasoning,
          );
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
        _presenter.syncResponse(
          loading: false,
          result: result.content,
          reasoning: result.reasoning,
        );
      }
      return result;
    } catch (error) {
      if (sendId == _latestSendId) {
        _presenter.syncResponse(
          loading: false,
          errorMessage: error.toString(),
        );
      }
      rethrow;
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
      _presenter.syncResponse(
        loading: false,
        result: _streamingText,
        reasoning: _streamingReasoning,
      );
      update(<String>[
        AiChatUpdateId.messages,
        AiChatUpdateId.status,
        AiChatUpdateId.input,
        AiChatUpdateId.suggestions,
      ]);
    }
    return stopped;
  }

  void newConversation() {
    // Let still-finishing old submit() Futures lose UI state ownership.
    _latestSendId++;
    _session.clear();
    _presenter.reset();
    _isGenerating = false;
    _streamingText = '';
    _streamingReasoning = '';
    _followUpSuggestions = const <String>[];
    update();
  }
}
