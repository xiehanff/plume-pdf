import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';

class _QueuedBackend implements AiBackend {
  final Completer<void> firstCancelGate = Completer<void>();
  final Completer<void> secondStarted = Completer<void>();
  late final StreamController<AiStreamEvent> firstStream =
      StreamController<AiStreamEvent>(
        onCancel: () => firstCancelGate.future,
      );
  late final StreamController<AiStreamEvent> secondStream =
      StreamController<AiStreamEvent>();
  int calls = 0;

  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) {
    calls++;
    if (calls == 1) {
      return firstStream.stream;
    }
    if (!secondStarted.isCompleted) {
      secondStarted.complete();
    }
    return secondStream.stream;
  }
}

class _SingleStreamBackend implements AiBackend {
  final StreamController<AiStreamEvent> stream =
      StreamController<AiStreamEvent>();

  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) => stream.stream;
}

void main() {
  test('old stopped Future cannot clear a newer send state', () async {
    final _QueuedBackend backend = _QueuedBackend();
    final AiChatController controller = AiChatController(
      session: AiChatSession(backend: backend),
    );

    final Future<AiChatTurnResult> first = controller.send(
      apiKey: 'key',
      input: const AiChatInput(text: 'first'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.isGenerating, isTrue);
    expect(controller.stop(), isTrue);
    expect(controller.isGenerating, isFalse);

    final Future<AiChatTurnResult> second = controller.send(
      apiKey: 'key',
      input: const AiChatInput(text: 'second'),
    );
    expect(controller.isGenerating, isTrue);

    backend.firstCancelGate.complete();
    await first;

    // The first Future finishes after the second send has taken ownership.
    expect(controller.isGenerating, isTrue);

    await backend.secondStarted.future;
    backend.secondStream
      ..add(const AiStreamEvent(text: 'second answer'))
      ..close();
    final AiChatTurnResult result = await second;

    expect(result.content, 'second answer');
    expect(controller.isGenerating, isFalse);
  });

  test('streaming controller hides follow-up protocol tags from UI state', () async {
    final _SingleStreamBackend backend = _SingleStreamBackend();
    final AiChatController controller = AiChatController(
      session: AiChatSession(backend: backend),
    );

    final Future<AiChatTurnResult> future = controller.send(
      apiKey: 'key',
      input: const AiChatInput(text: 'hello'),
    );
    await Future<void>.delayed(Duration.zero);

    backend.stream
      ..add(
        const AiStreamEvent(
          text:
              '正文<plume_follow_up_suggestions>["继续解释"]</plume_follow_up_suggestions>',
        ),
      )
      ..close();

    final AiChatTurnResult result = await future;
    expect(result.content, '正文');
    expect(controller.streamingText, '正文');
    expect(controller.followUpSuggestions, <String>['继续解释']);
  });
}
