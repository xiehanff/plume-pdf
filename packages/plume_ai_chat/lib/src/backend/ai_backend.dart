import '../models/ai_chat_history_message.dart';

/// Provider-neutral request passed from the chat runtime to a concrete backend.
class AiBackendRequest {
  const AiBackendRequest({
    required this.apiKey,
    required this.history,
    this.systemPrompt,
  });

  final String apiKey;
  final List<AiChatHistoryMessage> history;
  final String? systemPrompt;
}

/// Provider-neutral streaming event.
class AiStreamEvent {
  const AiStreamEvent({this.text = '', this.reasoning = ''});

  final String text;
  final String reasoning;
}

/// Transport boundary implemented by DeepSeek/OpenAI/Gemini/etc.
abstract interface class AiBackend {
  Stream<AiStreamEvent> chat(AiBackendRequest request);
}
