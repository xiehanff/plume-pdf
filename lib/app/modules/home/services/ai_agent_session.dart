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
    this.stopped = false,
  });

  final String content;
  final String reasoning;
  final List<String> followUpSuggestions;

  /// 用户是否主动停止了本轮生成。
  final bool stopped;
}

class _ActiveAiStream {
  final Completer<void> completion = Completer<void>();
  StreamSubscription<DeepSeekStreamChunk>? subscription;
  bool stopped = false;
}

/// AI 会话层：持有对话历史，负责流式累积、响应解析与历史写入。
///
/// 流式期间通过 onPreview 回调累积中的正文与推理过程，供 UI 做预览
/// 渲染；动作类请求成功后才把本轮 user/assistant 消息写入历史，
/// 对话类请求失败时回滚已入列的 user 消息。
///
/// [clear] 会递增会话代数并取消当前流：清空后旧流不会继续消耗网络
/// 增量，也不会把结果写进新会话的历史。
class AiAgentSession {
  AiAgentSession({DeepSeekService? deepSeekService})
    : _deepSeekService = deepSeekService ?? DeepSeekService();

  final DeepSeekService _deepSeekService;
  final List<AiChatHistoryMessage> _history = <AiChatHistoryMessage>[];
  int _generation = 0;
  _ActiveAiStream? _activeStream;

  List<AiChatHistoryMessage> get history => _history;

  void clear() {
    _history.clear();
    _generation++;
    stopActiveStream();
  }

  /// 立即停止当前流式请求。
  ///
  /// 返回 true 表示已经存在活跃的底层 stream，并已发起 subscription cancel；
  /// 返回 false 表示请求还未进入流式阶段或已经结束。取消动作本身异步收尾，
  /// 但 subscription 会立即进入取消流程，之后不会再向 UI 追加增量。
  bool stopActiveStream() {
    final _ActiveAiStream? active = _activeStream;
    if (active == null) {
      return false;
    }
    unawaited(_stopStream(active));
    return true;
  }

  /// 流式执行翻译/解释/深度理解动作。
  ///
  /// 本轮 user 消息只在成功后写入历史（含视觉模式的截图）。用户主动
  /// 停止时，若已经产生正文，则把当前部分正文作为本轮 assistant 历史；
  /// 尚未产生正文则不写入这一轮动作历史。
  Future<AiStreamResult> runToolAction({
    required AiToolAction action,
    required String apiKey,
    required String selectionText,
    String? pageContext,
    Uint8List? imageBytes,
    required void Function(String text, String reasoning) onPreview,
  }) async {
    final int requestGeneration = _generation;
    final int historyInsertIndex = _history.length;
    final AiStreamResult result = await _runStream(
      () => _deepSeekService.performStream(
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

    if (_generation != requestGeneration ||
        (result.stopped && result.content.trim().isEmpty)) {
      return result;
    }

    final bool isVisionMode = imageBytes != null && imageBytes.isNotEmpty;
    final AiChatHistoryMessage userMessage = isVisionMode
        ? AiChatHistoryMessage.user(
            content: AiPrompts.visionUserPrompt(action),
            image: AiImageAttachment(bytes: imageBytes, mimeType: 'image/png'),
          )
        : AiChatHistoryMessage.user(
            content: AiPrompts.userPrompt(
              action,
              selectionText,
              pageContext: pageContext,
            ),
          );
    _insertTurn(
      historyInsertIndex,
      userMessage,
      AiChatHistoryMessage.assistant(content: result.content),
    );
    return result;
  }

  /// 流式发送一轮多轮对话。user 消息先入历史再请求，失败时回滚。
  /// 用户主动停止且已有部分正文时，保留 user 与部分 assistant；如果
  /// 尚未返回正文，则回滚本轮 user，避免历史里留下悬空请求。
  ///
  /// assistant 始终插回本轮 user 后面，而不是无条件 append 到历史末尾。
  /// 因此 Stop 后 UI 立即允许下一次发送时，即使旧请求的 cancel 稍后才
  /// 完成，也不会形成 user1 → user2 → assistant1 的乱序历史。
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
        () => _deepSeekService.chatStream(
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
      if (result.stopped && result.content.trim().isEmpty) {
        _removeMessage(userMessage);
        return result;
      }
      _insertAssistantAfter(
        userMessage,
        AiChatHistoryMessage.assistant(content: result.content),
      );
      return result;
    } catch (_) {
      _removeMessage(userMessage);
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
  /// [isStale] 返回 true 时会取消底层订阅并提前结束。用户主动停止与
  /// stale 都通过同一 subscription cancel 路径收尾，确保 HTTP/SSE 不再
  /// 继续消费数据。正常结束时正文为空仍视为失败；主动停止允许空正文。
  Future<AiStreamResult> _runStream(
    Stream<DeepSeekStreamChunk> Function() stream, {
    required void Function(String text, String reasoning) onPreview,
    bool Function()? isStale,
  }) async {
    final StringBuffer textBuffer = StringBuffer();
    final StringBuffer reasoningBuffer = StringBuffer();
    final _ActiveAiStream active = _ActiveAiStream();

    Timer? previewTimer;
    bool previewDirty = false;
    void schedulePreview() {
      previewDirty = true;
      previewTimer ??= Timer(const Duration(milliseconds: 40), () {
        previewTimer = null;
        if (!previewDirty || active.stopped) {
          return;
        }
        previewDirty = false;
        onPreview(textBuffer.toString(), reasoningBuffer.toString());
      });
    }

    _activeStream = active;
    try {
      active.subscription = stream().listen(
        (DeepSeekStreamChunk chunk) {
          if (isStale != null && isStale()) {
            unawaited(_stopStream(active));
            return;
          }
          textBuffer.write(chunk.text);
          reasoningBuffer.write(chunk.reasoning);
          schedulePreview();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (active.completion.isCompleted) {
            return;
          }
          if (active.stopped) {
            active.completion.complete();
            return;
          }
          active.completion.completeError(error, stackTrace);
        },
        onDone: () {
          if (!active.completion.isCompleted) {
            active.completion.complete();
          }
        },
      );
      await active.completion.future;
    } finally {
      // 网络/解析异常、用户停止和正常完成都必须取消 pending preview，
      // 避免终态已经写入后，迟到的 Timer 又回调旧的流式内容。
      previewTimer?.cancel();
      if (!active.stopped) {
        await active.subscription?.cancel();
      }
      if (identical(_activeStream, active)) {
        _activeStream = null;
      }
    }

    final AiResponse response = AiResponseParser.parse(textBuffer.toString());
    final String content = response.content.trim();
    if (content.isEmpty && !active.stopped) {
      throw const DeepSeekException('DeepSeek 没有返回可展示的内容。');
    }
    return AiStreamResult(
      content: content,
      reasoning: reasoningBuffer.toString(),
      followUpSuggestions: active.stopped
          ? const <String>[]
          : response.followUpSuggestions,
      stopped: active.stopped,
    );
  }

  Future<void> _stopStream(_ActiveAiStream active) async {
    if (active.stopped) {
      return;
    }
    active.stopped = true;
    try {
      await active.subscription?.cancel();
    } catch (_) {
      // 用户主动停止的语义优先于 transport cancel 的收尾异常。
    } finally {
      if (!active.completion.isCompleted) {
        active.completion.complete();
      }
    }
  }

  void _insertTurn(
    int preferredIndex,
    AiChatHistoryMessage userMessage,
    AiChatHistoryMessage assistantMessage,
  ) {
    final int insertIndex = preferredIndex <= _history.length
        ? preferredIndex
        : _history.length;
    _history.insertAll(insertIndex, <AiChatHistoryMessage>[
      userMessage,
      assistantMessage,
    ]);
  }

  void _insertAssistantAfter(
    AiChatHistoryMessage userMessage,
    AiChatHistoryMessage assistantMessage,
  ) {
    final int userIndex = _history.indexWhere(
      (AiChatHistoryMessage message) => identical(message, userMessage),
    );
    if (userIndex < 0) {
      return;
    }
    _history.insert(userIndex + 1, assistantMessage);
  }

  void _removeMessage(AiChatHistoryMessage message) {
    final int index = _history.indexWhere(
      (AiChatHistoryMessage item) => identical(item, message),
    );
    if (index >= 0) {
      _history.removeAt(index);
    }
  }
}
