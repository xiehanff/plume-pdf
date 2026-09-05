import 'dart:typed_data';

import 'package:plume_ai_chat/plume_ai_chat.dart';

import '../models/pdf_ai_context.dart';
import 'ai_prompts.dart';
import 'deepseek_service.dart' show AiToolAction;

/// Plume-specific adapter between PDF reading semantics and the reusable
/// `plume_ai_chat` runtime.
///
/// PDF extraction/OCR/context building stays in the app. This adapter only
/// converts domain actions into generic chat turns so Tool Actions and normal
/// chat share one history, one Turn barrier and one transport implementation.
class PdfAiChatSession {
  PdfAiChatSession({AiChatSession? session})
    : _session =
          session ?? AiChatSession(backend: DeepSeekBackend());

  static const int _deepDiveMaxTokens = 32768;

  final AiChatSession _session;

  List<AiChatHistoryMessage> get history => _session.history;

  void clear() => _session.clear();

  bool stopActiveStream() => _session.stopActiveTurn();

  Future<AiChatTurnResult> runToolAction({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    Uint8List? imageBytes,
    required void Function(String text, String reasoning) onPreview,
  }) {
    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
    final String userPrompt = isVisionMode && selectionText.trim().isEmpty
        ? AiPrompts.visionUserPrompt(action)
        : AiPrompts.userPrompt(
            action,
            selectionText,
            pageContext: pageContext,
          );

    return _session.send(
      apiKey: apiKey,
      userMessage: AiChatHistoryMessage.user(
        content: userPrompt,
        image: isVisionMode
            ? AiImageAttachment(
                bytes: imageBytes,
                mimeType: 'image/png',
              )
            : null,
      ),
      systemPrompt: AiPrompts.systemPrompt(action),
      options: action == AiToolAction.deepDive
          ? const AiRequestOptions(
              maxOutputTokens: _deepDiveMaxTokens,
              providerOptions: <String, Object?>{
                'reasoning_effort': null,
              },
            )
          : const AiRequestOptions(),
      stopPrevious: true,
      deferHistoryCommit: true,
      onPreview: onPreview,
    );
  }

  Future<AiChatTurnResult> sendChat({
    required String apiKey,
    required AiChatHistoryMessage userMessage,
    PdfAiContext? documentContext,
    required void Function(String text, String reasoning) onPreview,
  }) {
    return _session.send(
      apiKey: apiKey,
      userMessage: userMessage,
      systemPrompt: AiPrompts.chatSystemPrompt(
        documentContext: documentContext,
      ),
      onPreview: onPreview,
    );
  }
}
