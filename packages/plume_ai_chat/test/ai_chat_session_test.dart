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
}
