import 'dart:typed_data';

import 'package:plume_ai_chat/plume_ai_chat.dart';

import '../models/pdf_ai_context.dart';
import 'ai_prompts.dart';
import 'deepseek_service.dart' show AiToolAction, DeepSeekException;

/// Plume 侧暂时保留的结果形状。
///
/// Home 层仍使用这个类型，内部已经由 `plume_ai_chat` 的
/// [AiChatTurnResult] 提供真实会话结果。等 UI/Controller 一并迁入 Package
/// 后再删除这层兼容映射。
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
///
/// PDF extraction/OCR/context building stays in the app. This adapter only
/// converts domain actions into generic chat turns so Tool Actions and normal
/// chat share one history, one Turn barrier and one transport implementation.
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
  }) async {
    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
    final String userPrompt = isVisionMode && selectionText.trim().isEmpty
        ? AiPrompts.visionUserPrompt(action)
        : AiPrompts.userPrompt(
            action,
            selectionText,
            pageContext: pageContext,
          );

    return _run(
      () => _session.send(
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
      () => _session.send(
        apiKey: apiKey,
        userMessage: userMessage,
        systemPrompt: AiPrompts.chatSystemPrompt(
          documentContext: documentContext,
        ),
        onPreview: onPreview,
      ),
    );
  }

  Future<AiStreamResult> _run(
    Future<AiChatTurnResult> Function() operation,
  ) async {
    try {
      final AiChatTurnResult result = await operation();
      return AiStreamResult(
        content: result.content,
        reasoning: result.reasoning,
        followUpSuggestions: result.followUpSuggestions,
        stopped: result.stopped,
      );
    } on DeepSeekBackendException catch (error) {
      // HomeController 现阶段仍按旧异常类型处理视觉 fallback 和错误文案。
      // 这层只做类型兼容，不重新发请求。
      throw DeepSeekException(error.message, statusCode: error.statusCode);
    } on AiChatException catch (error) {
      throw DeepSeekException(error.message);
    }
  }
}
