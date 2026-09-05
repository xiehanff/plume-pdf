import 'package:flutter_test/flutter_test.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';

void main() {
  test('streaming result replaces loading placeholder and keeps stable id', () {
    final AiConversationPresenter presenter = AiConversationPresenter();
    presenter.addUserMessage(text: 'hello');
    presenter.ensureLoadingPlaceholder();

    final String loadingId = presenter.messages.last.id;
    presenter.syncResponse(loading: true, result: 'a');
    presenter.syncResponse(loading: true, result: 'answer');

    expect(presenter.messages.length, 2);
    expect(presenter.messages.last.id, loadingId);
    expect(presenter.messages.last.text, 'answer');
    expect(presenter.messages.last.isLoading, isTrue);

    presenter.syncResponse(loading: false, result: 'answer');
    expect(presenter.messages.last.id, loadingId);
    expect(presenter.messages.last.isLoading, isFalse);
  });

  test('Stop before first visible token removes empty loading placeholder', () {
    final AiConversationPresenter presenter = AiConversationPresenter();
    presenter.addUserMessage(text: 'hello');
    presenter.ensureLoadingPlaceholder();

    presenter.syncResponse(loading: false);

    expect(presenter.messages.length, 1);
    expect(presenter.messages.single.author, MessageAuthor.human);
  });

  test('reasoning-only preview survives until completion', () {
    final AiConversationPresenter presenter = AiConversationPresenter();
    presenter.addUserMessage(text: 'hello');

    presenter.syncResponse(loading: true, reasoning: 'thinking');
    expect(presenter.messages.last.reasoning, 'thinking');
    expect(presenter.messages.last.isLoading, isTrue);

    presenter.syncResponse(loading: false, reasoning: 'thinking');
    expect(presenter.messages.last.reasoning, 'thinking');
    expect(presenter.messages.last.isLoading, isFalse);
  });

  test('error replaces loading placeholder', () {
    final AiConversationPresenter presenter = AiConversationPresenter();
    presenter.addUserMessage(text: 'hello');
    presenter.ensureLoadingPlaceholder();

    presenter.syncResponse(
      loading: false,
      errorMessage: 'network failed',
    );

    expect(presenter.messages.last.text, '❌ network failed');
    expect(presenter.messages.last.isLoading, isFalse);
  });
}
