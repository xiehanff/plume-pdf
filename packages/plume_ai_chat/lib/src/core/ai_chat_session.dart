import 'dart:async';

import '../backend/ai_backend.dart';
import '../models/ai_chat_history_message.dart';
import 'ai_response_parser.dart';

class AiChatTurnResult {
  const AiChatTurnResult({
    required this.content,
    required this.reasoning,
    this.followUpSuggestions = const <String>[],
    this.stopped = false,
  });

  final String content;
  final String reasoning;
  final List<String> followUpSuggestions;
  final bool stopped;
}

class AiChatException implements Exception {
  const AiChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ActiveTurn {
  final Completer<void> completion = Completer<void>();
  StreamSubscription<AiStreamEvent>? subscription;
  bool stopped = false;
}

class _TurnGate {
  final Completer<void> completion = Completer<void>();
  bool started = false;
  bool stoppedBeforeStart = false;
}

/// Framework-independent conversation runtime.
///
/// It owns history ordering, Stop semantics and the turn barrier. UI frameworks
/// such as GetX belong above this layer.
class AiChatSession {
  AiChatSession({required AiBackend backend}) : _backend = backend;

  static const AiChatTurnResult _stoppedBeforeStart = AiChatTurnResult(
    content: '',
    reasoning: '',
    stopped: true,
  );

  final AiBackend _backend;
  final List<AiChatHistoryMessage> _history = <AiChatHistoryMessage>[];
  int _generation = 0;
  _ActiveTurn? _activeTurn;
  Future<void> _turnTail = Future<void>.value();
  _TurnGate? _latestTurn;

  List<AiChatHistoryMessage> get history =>
      List<AiChatHistoryMessage>.unmodifiable(_history);

  void clear() {
    _history.clear();
    _generation++;

    final _TurnGate? latestTurn = _latestTurn;
    if (latestTurn != null && !latestTurn.started) {
      latestTurn.stoppedBeforeStart = true;
    }
    _latestTurn = null;

    final _ActiveTurn? active = _activeTurn;
    if (active != null && !active.stopped) {
      unawaited(_stopTurn(active));
    }

    _turnTail = Future<void>.value();
  }

  bool stopActiveTurn() {
    final _TurnGate? latestTurn = _latestTurn;
    if (latestTurn != null &&
        !latestTurn.started &&
        !latestTurn.stoppedBeforeStart) {
      latestTurn.stoppedBeforeStart = true;
      return true;
    }

    final _ActiveTurn? active = _activeTurn;
    if (active == null || active.stopped) {
      return false;
    }
    unawaited(_stopTurn(active));
    return true;
  }

  Future<AiChatTurnResult> send({
    required String apiKey,
    required AiChatHistoryMessage userMessage,
    String? systemPrompt,
    required void Function(String text, String reasoning) onPreview,
  }) {
    final int requestGeneration = _generation;
    return _runTurn(requestGeneration, () async {
      _history.add(userMessage);
      final List<AiChatHistoryMessage> snapshot =
          List<AiChatHistoryMessage>.unmodifiable(_history);
      try {
        final AiChatTurnResult result = await _runStream(
          _backend.chat(
            AiBackendRequest(
              apiKey: apiKey,
              history: snapshot,
              systemPrompt: systemPrompt,
            ),
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
        _history.add(
          AiChatHistoryMessage.assistant(content: result.content),
        );
        return result;
      } catch (_) {
        _removeMessage(userMessage);
        rethrow;
      }
    });
  }

  Future<AiChatTurnResult> _runTurn(
    int requestGeneration,
    Future<AiChatTurnResult> Function() operation,
  ) {
    final Future<void> previousTurn = _turnTail;
    final _TurnGate turn = _TurnGate();
    _turnTail = turn.completion.future;
    _latestTurn = turn;

    return () async {
      await previousTurn;
      try {
        if (turn.stoppedBeforeStart || _generation != requestGeneration) {
          return _stoppedBeforeStart;
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

  Future<AiChatTurnResult> _runStream(
    Stream<AiStreamEvent> stream, {
    required void Function(String text, String reasoning) onPreview,
    bool Function()? isStale,
  }) async {
    final StringBuffer textBuffer = StringBuffer();
    final StringBuffer reasoningBuffer = StringBuffer();
    final _ActiveTurn active = _ActiveTurn();

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

    _activeTurn = active;
    try {
      active.subscription = stream.listen(
        (AiStreamEvent event) {
          if (isStale != null && isStale()) {
            unawaited(_stopTurn(active));
            return;
          }
          textBuffer.write(event.text);
          reasoningBuffer.write(event.reasoning);
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
      previewTimer?.cancel();
      if (!active.stopped) {
        await active.subscription?.cancel();
      }
      if (identical(_activeTurn, active)) {
        _activeTurn = null;
      }
    }

    final AiResponse response = AiResponseParser.parse(textBuffer.toString());
    final String content = response.content.trim();
    if (content.isEmpty && !active.stopped) {
      throw const AiChatException('AI 没有返回可展示的内容。');
    }
    return AiChatTurnResult(
      content: content,
      reasoning: reasoningBuffer.toString(),
      followUpSuggestions: active.stopped
          ? const <String>[]
          : response.followUpSuggestions,
      stopped: active.stopped,
    );
  }

  Future<void> _stopTurn(_ActiveTurn active) async {
    if (active.stopped) {
      return;
    }
    active.stopped = true;
    try {
      await active.subscription?.cancel();
    } catch (_) {
      // Stop is user intent; transport cancellation errors do not override it.
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
