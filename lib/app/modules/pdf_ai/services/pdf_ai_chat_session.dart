import 'dart:typed_data';

import 'package:plume_ai_chat/plume_ai_chat.dart';

import '../models/pdf_ai_context.dart';
import '../models/pdf_ai_tool_action.dart';
import 'ai_prompts.dart';

/// Plume 侧暂时保留的结果形状。
///
/// Reader 编排层仍使用这个类型，内部已经由 `plume_ai_chat` 的
/// [AiChatTurnResult] 提供真实会话结果。等 App 侧状态进一步收敛后再删除
/// 这层兼容映射。
class AiStreamResult {
  const AiStreamResult({
    required this.content,
    required this.reasoning,
    required this.followUpSuggestions,
    this.stopped = false,
  });

  final String content;
  final String reasoning;
  final List<String> followUpSuggestions;
  final bool stopped;
}

/// Plume-specific adapter between PDF reading semantics and the reusable
/// `plume_ai_chat` runtime.
class PdfAiChatSession {
  PdfAiChatSession({AiChatSession? session})
    : _session = session ?? AiChatSession(backend: DeepSeekBackend());

  static const int _deepDiveMaxTokens = 32768;

  final AiChatSession _session;

  List<AiChatHistoryMessage> get history => _session.history;

  void clear() => _session.clear();

  bool stopActiveStream() => _session.stopActiveTurn();

  Future<AiStreamResult> runToolAction({
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

    return _run(
      _session.send(
        apiKey: apiKey,
        userMessage: AiChatHistoryMessage.user(
          content: userPrompt,
          image: isVisionMode
              ? AiImageAttachment(bytes: imageBytes, mimeType: 'image/png')
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
      ),
    );
  }

  Future<AiStreamResult> sendChat({
    required String apiKey,
    required AiChatHistoryMessage userMessage,
    PdfAiContext? documentContext,
    required void Function(String text, String reasoning) onPreview,
  }) {
    return _run(
      _session.send(
        apiKey: apiKey,
        userMessage: userMessage,
        systemPrompt: AiPrompts.chatSystemPrompt(
          documentContext: documentContext,
        ),
        onPreview: onPreview,
      ),
    );
  }

  Future<AiStreamResult> _run(Future<AiChatTurnResult> operation) async {
    final AiChatTurnResult result = await operation;
    return AiStreamResult(
      content: result.content,
      reasoning: result.reasoning,
      followUpSuggestions: result.followUpSuggestions,
      stopped: result.stopped,
    );
  }
}
