enum MessageAuthor { human, ai }

class ChatMessage {
  ChatMessage({
    required this.author,
    required this.text,
    required this.id,
    this.isLoading = false,
  });

  final MessageAuthor author;
  final String text;
  final String id;
  final bool isLoading;
}
