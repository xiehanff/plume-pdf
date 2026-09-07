import 'dart:typed_data';

import 'package:plume_ai_chat/plume_ai_chat.dart';

import '../models/pdf_ai_context.dart';
import '../models/pdf_ai_tool_action.dart';
import 'ai_prompts.dart';

typedef PdfAiPageContextProvider = Future<String?> Function();
typedef PdfAiDocumentContextProvider = Future<PdfAiContext?> Function();

/// Plume-specific adapter between PDF reading semantics and the reusable
/// `plume_ai_chat` controller/runtime.
///
/// This adapter owns prompt/domain translation only. Conversation presentation,
/// loading/Stop state, history and streaming updates are all owned by the shared
/// [AiChatController].
class PdfAiChatSession {
  PdfAiChatSession({required AiChatController controller})
    : _controller = controller;

  static const int _deepDiveMaxTokens = 32768;

  final AiChatController _controller;

  bool get isGenerating => _controller.isGenerating;
  List<AiChatHistoryMessage> get history => _controller.history;

  void clear() => _controller.newConversation();

  bool stopActiveStream() => _controller.stop();

  Future<AiChatTurnResult> runToolAction({
    required AiToolAction action,
    required String selectionText,
    Uint8List? imageBytes,
    PdfAiPageContextProvider? pageContextProvider,
  }) {
    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
    final String displayText = isVisionMode
        ? ''
        : _actionDisplayText(action, selectionText);
    final AiChatSubmission initialSubmission = isVisionMode
        ? _visionSubmission(
            action: action,
            imageBytes: imageBytes,
            displayText: displayText,
          )
        : _textSubmission(
            action: action,
            selectionText: selectionText,
            displayText: displayText,
          );

    return _controller.submit(
      submission: initialSubmission,
      prepareSubmission: isVisionMode
          ? null
          : () async {
              if (selectionText.trim().isEmpty) {
                throw const AiChatException('当前框选区域没有识别到可用文本。');
              }
              final String? pageContext = await pageContextProvider?.call();
              return _textSubmission(
                action: action,
                selectionText: selectionText,
                pageContext: pageContext,
                displayText: displayText,
              );
            },
      fallbackBuilder: isVisionMode && selectionText.trim().isNotEmpty
          ? (Object error) async {
              if (error is! DeepSeekBackendException ||
                  !error.canFallbackToText) {
                return null;
              }
              final String? pageContext = await pageContextProvider?.call();
              return _textSubmission(
                action: action,
                selectionText: selectionText,
                pageContext: pageContext,
                displayText: displayText,
              );
            }
          : null,
    );
  }

  Future<AiChatTurnResult> sendChat({
    required AiChatInput input,
    required PdfAiDocumentContextProvider documentContextProvider,
  }) {
    final String trimmedMessage = input.text.trim();
    final String historyMessage = trimmedMessage.isEmpty && input.image != null
        ? '请分析这张图片。'
        : trimmedMessage;
    final AiChatHistoryMessage userMessage = AiChatHistoryMessage.user(
      content: historyMessage,
      image: input.image,
    );
    final AiChatSubmission initialSubmission = AiChatSubmission(
      userMessage: userMessage,
      displayText: historyMessage,
      displayImageBytes: input.image?.bytes,
      systemPrompt: AiPrompts.chatSystemPrompt(),
    );

    return _controller.submit(
      submission: initialSubmission,
      prepareSubmission: () async {
        final PdfAiContext? documentContext = await documentContextProvider();
        return AiChatSubmission(
          userMessage: userMessage,
          displayText: historyMessage,
          displayImageBytes: input.image?.bytes,
          systemPrompt: AiPrompts.chatSystemPrompt(
            documentContext: documentContext,
          ),
        );
      },
    );
  }

  AiChatSubmission _visionSubmission({
    required AiToolAction action,
    required Uint8List imageBytes,
    required String displayText,
  }) {
    return AiChatSubmission(
      userMessage: AiChatHistoryMessage.user(
        content: AiPrompts.visionUserPrompt(action),
        image: AiImageAttachment(bytes: imageBytes, mimeType: 'image/png'),
      ),
      displayText: displayText,
      displayImageBytes: imageBytes,
      systemPrompt: AiPrompts.systemPrompt(action),
      options: _optionsFor(action),
      stopPrevious: true,
      deferHistoryCommit: true,
    );
  }

  AiChatSubmission _textSubmission({
    required AiToolAction action,
    required String selectionText,
    required String displayText,
    String? pageContext,
  }) {
    return AiChatSubmission(
      userMessage: AiChatHistoryMessage.user(
        content: AiPrompts.userPrompt(
          action,
          selectionText,
          pageContext: pageContext,
        ),
      ),
      displayText: displayText,
      systemPrompt: AiPrompts.systemPrompt(action),
      options: _optionsFor(action),
      stopPrevious: true,
      deferHistoryCommit: true,
    );
  }

  AiRequestOptions _optionsFor(AiToolAction action) {
    return action == AiToolAction.deepDive
        ? const AiRequestOptions(
            maxOutputTokens: _deepDiveMaxTokens,
            providerOptions: <String, Object?>{'reasoning_effort': null},
          )
        : const AiRequestOptions();
  }

  String _actionDisplayText(AiToolAction action, String selectionText) {
    final String singleLine = selectionText
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (singleLine.isEmpty) {
      return action.label;
    }
    final String shortened = singleLine.length <= 80
        ? singleLine
        : '${singleLine.substring(0, 80)}…';
    return '${action.label} $shortened';
  }
}
