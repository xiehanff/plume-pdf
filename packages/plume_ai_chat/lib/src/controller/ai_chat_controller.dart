import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../backend/ai_backend.dart';
import '../core/ai_chat_session.dart';
import '../core/ai_response_parser.dart';
import '../models/ai_chat_history_message.dart';
import '../models/ai_chat_input.dart';
import '../models/ai_chat_submission.dart';
import '../models/chat_message.dart';
import 'ai_conversation_presenter.dart';

typedef AiChatSubmissionPreparer = FutureOr<AiChatSubmission> Function();
typedef AiChatFallbackBuilder = FutureOr<AiChatSubmission?> Function(
  Object error,
);

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

  static const AiChatTurnResult _stoppedBeforeTransport = AiChatTurnResult(
    content: '',
    reasoning: '',
    stopped: true,
  );

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
  /// [prepareSubmission] runs after the user bubble/loading placeholder are
  /// already visible. Hosts can therefore asynchronously build document
  /// context, read attachments or resolve account state without maintaining a
  /// second "preparing" conversation model. Stop/new-conversation/dispose
  /// invalidate that preparation before it can reach transport.
  ///
  /// [fallbackBuilder] can replace a failed transport submission while keeping
  /// the same presentation turn. It is intentionally only consulted before any
  /// streamed text/reasoning has been displayed, so a retry can never erase a
  /// partial answer the user has already seen.
  Future<AiChatTurnResult> submit({
    required AiChatSubmission submission,
    AiChatSubmissionPreparer? prepareSubmission,
    AiChatFallbackBuilder? fallbackBuilder,
  }) async {
    if (_isGenerating && !submission.stopPrevious) {
      return const AiChatTurnResult(content: '', reasoning: '');
    }

    // Latest-wins must finalize/remove the previous presentation placeholder
    // before appending the new user turn. Otherwise the new response can reuse
    // the old loading bubble and appear above the new user message.
    if (_isGenerating && submission.stopPrevious) {
      stop();
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
    _notifyConversationChanged();

    try {
      final AiChatSubmission preparedSubmission = prepareSubmission == null
          ? submission
          : await prepareSubmission();
      if (sendId != _latestSendId) {
        return _stoppedBeforeTransport;
      }

      final AiChatTurnResult result = await _executeSubmission(
        sendId: sendId,
        submission: preparedSubmission,
        fallbackBuilder: fallbackBuilder,
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
      if (sendId == _latestSendId) {
        _isGenerating = false;
        _notifyConversationChanged();
      }
    }
  }

  Future<AiChatTurnResult> _executeSubmission({
    required int sendId,
    required AiChatSubmission submission,
    AiChatFallbackBuilder? fallbackBuilder,
  }) async {
    try {
      return await _sendSubmission(sendId: sendId, submission: submission);
    } catch (error) {
      if (sendId != _latestSendId ||
          fallbackBuilder == null ||
          _streamingText.trim().isNotEmpty ||
          _streamingReasoning.trim().isNotEmpty) {
        rethrow;
      }

      final AiChatSubmission? fallback = await fallbackBuilder(error);
      if (sendId != _latestSendId) {
        return _stoppedBeforeTransport;
      }
      if (fallback == null) {
        rethrow;
      }
      return _sendSubmission(sendId: sendId, submission: fallback);
    }
  }

  Future<AiChatTurnResult> _sendSubmission({
    required int sendId,
    required AiChatSubmission submission,
  }) {
    return _session.send(
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
  }

  /// Adds a host-side failure (for example document/OCR preparation failure)
  /// to the same generic conversation presentation without touching transport
  /// history.
  void presentLocalError({
    required String message,
    String? displayText,
    Uint8List? displayImageBytes,
    bool stopPrevious = false,
  }) {
    if (_isGenerating && stopPrevious) {
      stop();
    }
    final String visibleText = displayText?.trim() ?? '';
    if (visibleText.isNotEmpty || displayImageBytes != null) {
      _presenter.addUserMessage(
        text: visibleText,
        imageBytes: displayImageBytes,
      );
    }
    _presenter
      ..ensureLoadingPlaceholder()
      ..syncResponse(loading: false, errorMessage: message);
    _followUpSuggestions = const <String>[];
    _notifyConversationChanged();
  }

  /// Stops either active transport or an asynchronous pre-transport
  /// preparation owned by this controller.
  bool stop() {
    if (!_isGenerating) {
      return false;
    }

    _session.stopActiveTurn();
    _latestSendId++;
    _isGenerating = false;
    _followUpSuggestions = const <String>[];
    _presenter.syncResponse(
      loading: false,
      result: _streamingText,
      reasoning: _streamingReasoning,
    );
    _notifyConversationChanged();
    return true;
  }

  void newConversation() {
    _resetConversation(notify: true);
  }

  @override
  void onClose() {
    // Controller disposal owns the runtime lifecycle too: no network stream or
    // pending turn may outlive a host-owned GetX controller.
    _resetConversation(notify: false);
    super.onClose();
  }

  void _resetConversation({required bool notify}) {
    _latestSendId++;
    _session.clear();
    _presenter.reset();
    _isGenerating = false;
    _streamingText = '';
    _streamingReasoning = '';
    _followUpSuggestions = const <String>[];
    if (notify) {
      _notifyConversationChanged();
    }
  }

  void _notifyConversationChanged() {
    update(<String>[
      AiChatUpdateId.messages,
      AiChatUpdateId.status,
      AiChatUpdateId.input,
      AiChatUpdateId.suggestions,
    ]);
  }
}
