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

class _AiTurnGate {
  final Completer<void> completion = Completer<void>();
  bool started = false;
  bool stoppedBeforeStart = false;
}

/// AI 会话层：持有对话历史，负责流式累积、响应解析与历史写入。
///
/// 流式期间通过 onPreview 回调累积中的正文与推理过程，供 UI 做预览
/// 渲染；动作类请求成功后才把本轮 user/assistant 消息写入历史，
/// 对话类请求失败时回滚已入列的 user 消息。
///
/// 每一轮 Turn 在真正发起模型请求前会等待上一轮完成 history commit / 
/// rollback。这样 Stop 后 UI 可以立即恢复，但下一轮不会拿到尚未收尾的
/// history，也不需要依赖事后插入下标来修正顺序。
///
/// [clear] 会递增会话代数并取消当前流；旧队列会因 generation 失效，
/// 新会话不必等待旧 transport 的异步取消收尾。
class AiAgentSession {
  AiAgentSession({DeepSeekService? deepSeekService})
    : _deepSeekService = deepSeekService ?? DeepSeekService();

  static const AiStreamResult _stoppedBeforeStartResult = AiStreamResult(
    content: '',
    reasoning: '',
    followUpSuggestions: <String>[],
    stopped: true,
  );

  final DeepSeekService _deepSeekService;
  final List<AiChatHistoryMessage> _history = <AiChatHistoryMessage>[];
  int _generation = 0;
  _ActiveAiStream? _activeStream;
  Future<void> _turnTail = Future<void>.value();
  _AiTurnGate? _latestTurn;

  List<AiChatHistoryMessage> get history => _history;

  void clear() {
    _history.clear();
    _generation++;

    // 已排队但尚未开始的旧 Turn 直接失效；generation 也会拦住其他旧队列。
    final _AiTurnGate? latestTurn = _latestTurn;
    if (latestTurn != null && !latestTurn.started) {
      latestTurn.stoppedBeforeStart = true;
    }
    _latestTurn = null;

    final _ActiveAiStream? active = _activeStream;
    if (active != null && !active.stopped) {
      unawaited(_stopStream(active));
    }

    // 新会话拥有独立的 Turn 链，不等待旧会话 transport cancel 收尾。
    _turnTail = Future<void>.value();
  }

  /// 立即停止当前生成。
  ///
  /// 已进入 SSE 时取消底层 subscription；如果下一轮正在等待上一轮完成
  /// history 收尾，则直接标记该等待中的 Turn 为停止，保证它不会再发起
  /// 网络请求。返回 true 表示本次停止命中了一个 active/pending Turn。
  bool stopActiveStream() {
    final _AiTurnGate? latestTurn = _latestTurn;
    if (latestTurn != null &&
        !latestTurn.started &&
        !latestTurn.stoppedBeforeStart) {
      latestTurn.stoppedBeforeStart = true;
      return true;
    }

    final _ActiveAiStream? active = _activeStream;
    if (active == null || active.stopped) {
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
  }) {
    final int requestGeneration = _generation;
    return _runTurn(requestGeneration, () async {
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
      _history
        ..add(userMessage)
        ..add(AiChatHistoryMessage.assistant(content: result.content));
      return result;
    });
  }

  /// 流式发送一轮多轮对话。上一轮 history 收尾完成后，本轮 user 才入列
  /// 并 snapshot 给 transport。失败或首 token 前停止时按 identity 回滚。
  Future<AiStreamResult> sendChat({
    required String apiKey,
    required AiChatHistoryMessage userMessage,
    PdfAiContext? documentContext,
    required void Function(String text, String reasoning) onPreview,
  }) {
    final int requestGeneration = _generation;
    return _runTurn(requestGeneration, () async {
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
        _history.add(AiChatHistoryMessage.assistant(content: result.content));
        return result;
      } catch (_) {
        _removeMessage(userMessage);
        rethrow;
      }
    });
  }

  /// 串行化 Turn 的 history 边界，而不是串行 UI。
  ///
  /// 调用方可以在 Stop 后立刻恢复按钮并创建下一轮 Future，但下一轮的
  /// [operation] 只有在上一轮完成 partial commit / rollback 后才运行。
  Future<AiStreamResult> _runTurn(
    int requestGeneration,
    Future<AiStreamResult> Function() operation,
  ) {
    final Future<void> previousTurn = _turnTail;
    final _AiTurnGate turn = _AiTurnGate();
    _turnTail = turn.completion.future;
    _latestTurn = turn;

    return () async {
      await previousTurn;
      try {
        if (turn.stoppedBeforeStart || _generation != requestGeneration) {
          return _stoppedBeforeStartResult;
        }
        turn.started = true;
        return await operation();
      } finally {
        if (identical(_latestTurn, turn)) {
          _latestTurn = null;
        }
        if (!turn.completion.isCompleted) {
          turn.completion.complete();
        }
      }
    }();
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

  void _removeMessage(AiChatHistoryMessage message) {
    final int index = _history.indexWhere(
      (AiChatHistoryMessage item) => identical(item, message),
    );
    if (index >= 0) {
      _history.removeAt(index);
    }
  }
}
