import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';

class _FakeBackend implements AiBackend {
  final List<AiBackendRequest> requests = <AiBackendRequest>[];
  final List<StreamController<AiStreamEvent>> streams =
      <StreamController<AiStreamEvent>>[];

  @override
  Stream<AiStreamEvent> chat(AiBackendRequest request) {
    requests.add(request);
    final StreamController<AiStreamEvent> controller =
        StreamController<AiStreamEvent>();
    streams.add(controller);
    return controller.stream;
  }
}

void main() {
  test('commits user and assistant history in order', () async {
    final _FakeBackend backend = _FakeBackend();
    final AiChatSession session = AiChatSession(backend: backend);

    final Future<AiChatTurnResult> future = session.send(
      apiKey: 'key',
      userMessage: const AiChatHistoryMessage.user(content: 'hello'),
      onPreview: (_, __) {},
    );

    await Future<void>.delayed(Duration.zero);
    backend.streams.single
      ..add(const AiStreamEvent(text: 'hi'))
      ..close();

    final AiChatTurnResult result = await future;
    expect(result.content, 'hi');
    expect(session.history.map((e) => e.content), <String>['hello', 'hi']);
  });

  test('Stop before first content rolls back the user turn', () async {
    final _FakeBackend backend = _FakeBackend();
    final AiChatSession session = AiChatSession(backend: backend);

    final Future<AiChatTurnResult> future = session.send(
      apiKey: 'key',
      userMessage: const AiChatHistoryMessage.user(content: 'hello'),
      onPreview: (_, __) {},
    );

    await Future<void>.delayed(Duration.zero);
    expect(session.stopActiveTurn(), isTrue);

    final AiChatTurnResult result = await future;
    expect(result.stopped, isTrue);
    expect(session.history, isEmpty);
  });

  test('deferred turn is visible to transport but not public history before commit', () async {
    final _FakeBackend backend = _FakeBackend();
    final AiChatSession session = AiChatSession(backend: backend);

    final Future<AiChatTurnResult> future = session.send(
      apiKey: 'key',
      userMessage: const AiChatHistoryMessage.user(content: 'tool prompt'),
      deferHistoryCommit: true,
      onPreview: (_, __) {},
    );

    await Future<void>.delayed(Duration.zero);
    expect(session.history, isEmpty);
    expect(backend.requests.single.history.single.content, 'tool prompt');

    backend.streams.single
      ..add(const AiStreamEvent(text: 'answer'))
      ..close();
    await future;

    expect(
      session.history.map((AiChatHistoryMessage e) => e.content),
      <String>['tool prompt', 'answer'],
    );
  });

  test('latest-wins stops a pending tool turn before it reaches transport', () async {
    final _FakeBackend backend = _FakeBackend();
    final AiChatSession session = AiChatSession(backend: backend);

    final Future<AiChatTurnResult> first = session.send(
      apiKey: 'key',
      userMessage: const AiChatHistoryMessage.user(content: 'A'),
      stopPrevious: true,
      deferHistoryCommit: true,
      onPreview: (_, __) {},
    );
    await Future<void>.delayed(Duration.zero);

    final Future<AiChatTurnResult> second = session.send(
      apiKey: 'key',
      userMessage: const AiChatHistoryMessage.user(content: 'B'),
      stopPrevious: true,
      deferHistoryCommit: true,
      onPreview: (_, __) {},
    );
    final Future<AiChatTurnResult> third = session.send(
      apiKey: 'key',
      userMessage: const AiChatHistoryMessage.user(content: 'C'),
      stopPrevious: true,
      deferHistoryCommit: true,
      onPreview: (_, __) {},
    );

    final AiChatTurnResult firstResult = await first;
    expect(firstResult.stopped, isTrue);
    final AiChatTurnResult secondResult = await second;
    expect(secondResult.stopped, isTrue);

    await Future<void>.delayed(Duration.zero);
    expect(backend.requests.map((AiBackendRequest e) => e.history.last.content), <String>['A', 'C']);

    backend.streams.last
      ..add(const AiStreamEvent(text: 'done'))
      ..close();
    final AiChatTurnResult thirdResult = await third;
    expect(thirdResult.content, 'done');
  });
}
