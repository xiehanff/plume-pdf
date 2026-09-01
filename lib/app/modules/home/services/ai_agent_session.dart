import 'dart:async';
import 'dart:typed_data';

import '../models/ai_chat_history_message.dart';
import '../models/ai_chat_input.dart' show AiImageAttachment;
import '../models/pdf_ai_context.dart';
import 'ai_prompts.dart';
import 'ai_response_parser.dart';
import 'deepseek_service.dart';

/// 一次流式请求的聚合结果：解析后的正文与建议，以及完整推理过程。
class AiStreamResult {
  const AiStreamResult({
    required this.content,
    required this.reasoning,
    required this.followUpSuggestions,
  });

  final String content;
  final String reasoning;
  final List<String> followUpSuggestions;
}

/// AI 会话层：持有对话历史，负责流式累积、响应解析与历史写入。
///
/// 流式期间通过 onPreview 回调累积中的正文与推理过程，供 UI 做预览
/// 渲染；动作类请求成功后才把本轮 user/assistant 消息写入历史，
/// 对话类请求失败时回滚已入列的 user 消息。
///
/// [clear] 会递增会话代数：清空后仍在进行的旧流将停止消费增量，
/// 也不会把结果写进新会话的历史。
class AiAgentSession {
  AiAgentSession({DeepSeekService? deepSeekService})
    : _deepSeekService = deepSeekService ?? DeepSeekService();

  final DeepSeekService _deepSeekService;
  final List<AiChatHistoryMessage> _history = <AiChatHistoryMessage>[];
  int _generation = 0;

  List<AiChatHistoryMessage> get history => _history;

  void clear() {
    _history.clear();
    _generation++;
  }

  /// 流式执行翻译/解释/深度理解动作。
  ///
  /// 本轮 user 消息只在成功后写入历史（含视觉模式的截图），
  /// 失败时历史保持不变。
  Future<AiStreamResult> runToolAction({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    Uint8List? imageBytes,
    required void Function(String text, String reasoning) onPreview,
  }) async {
    final int requestGeneration = _generation;
    final AiStreamResult result = await _runStream(
      () => _deepSeekService.performStreamWithReasoning(
        action: action,
        apiKey: apiKey,
        selectionText: selectionText,
        pageContext: pageContext,
        history: _history,
        imageBytes: imageBytes,
      ),
      onPreview: onPreview,
      isStale: () => _generation != requestGeneration,
    );

    if (_generation != requestGeneration) {
      return result;
    }

    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
    if (isVisionMode) {
      _history.add(
        AiChatHistoryMessage.user(
          content: AiPrompts.visionUserPrompt(action),
          image: AiImageAttachment(bytes: imageBytes, mimeType: 'image/png'),
        ),
      );
    } else {
      _history.add(
        AiChatHistoryMessage.user(
          content: AiPrompts.userPrompt(
            action,
            selectionText,
            pageContext: pageContext,
          ),
        ),
      );
    }
    _history.add(AiChatHistoryMessage.assistant(content: result.content));
    return result;
  }

  /// 流式发送一轮多轮对话。user 消息先入历史再请求，失败时回滚。
  Future<AiStreamResult> sendChat({
    required String apiKey,
    required AiChatHistoryMessage userMessage,
    PdfAiContext? documentContext,
    required void Function(String text, String reasoning) onPreview,
  }) async {
    final int requestGeneration = _generation;
    _history.add(userMessage);
    try {
      final AiStreamResult result = await _runStream(
        () => _deepSeekService.chatStreamWithReasoning(
          apiKey: apiKey,
          history: _history,
          documentContext: documentContext,
        ),
        onPreview: onPreview,
        isStale: () => _generation != requestGeneration,
      );
      if (_generation != requestGeneration) {
        return result;
      }
      _history.add(AiChatHistoryMessage.assistant(content: result.content));
      return result;
    } catch (_) {
      _removePending(userMessage);
      rethrow;
    }
  }

  /// 累积一段流式响应：逐块回调预览，结束后解析正文与追问建议。
  ///
  /// 网络层 chunk 频率可达每秒上百次，逐个回调会让 UI 刷新与全量
  /// Markdown 重解析一起打满主线程。这里以 ~40ms 窗口合并 preview
  /// 回调（首块后 40ms 触发，之后每窗口至多一次），肉眼仍是流式，
  /// 主线程压力大幅下降；流结束后取消待发回调，终态由调用方直接
  /// 写入完整结果。
  ///
  /// [isStale] 返回 true 时停止消费流（取消底层订阅）并提前结束；
  /// 正文为空视为失败，抛出 [DeepSeekException] 由调用方处理。
  Future<AiStreamResult> _runStream(
    Stream<DeepSeekStreamChunk> Function() stream, {
    required void Function(String text, String reasoning) onPreview,
    bool Function()? isStale,
  }) async {
    final StringBuffer textBuffer = StringBuffer();
    final StringBuffer reasoningBuffer = StringBuffer();

    Timer? previewTimer;
    bool previewDirty = false;
    void schedulePreview() {
      previewDirty = true;
      previewTimer ??= Timer(const Duration(milliseconds: 40), () {
        previewTimer = null;
        if (!previewDirty) {
          return;
        }
        previewDirty = false;
        onPreview(textBuffer.toString(), reasoningBuffer.toString());
      });
    }

    await for (final DeepSeekStreamChunk chunk in stream()) {
      if (isStale != null && isStale()) {
        break;
      }
      textBuffer.write(chunk.text);
      reasoningBuffer.write(chunk.reasoning);
      schedulePreview();
    }
    previewTimer?.cancel();

    final AiResponse response = AiResponseParser.parse(textBuffer.toString());
    final String content = response.content.trim();
    if (content.isEmpty) {
      throw const DeepSeekException('DeepSeek 没有返回可展示的内容。');
    }
    return AiStreamResult(
      content: content,
      reasoning: reasoningBuffer.toString(),
      followUpSuggestions: response.followUpSuggestions,
    );
  }

  void _removePending(AiChatHistoryMessage message) {
    if (_history.isNotEmpty && identical(_history.last, message)) {
      _history.removeLast();
    }
  }
}
