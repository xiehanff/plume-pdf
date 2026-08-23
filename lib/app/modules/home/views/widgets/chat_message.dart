import 'dart:typed_data';

enum MessageAuthor { human, ai }

class ChatMessage {
  ChatMessage({
    required this.author,
    required this.text,
    required this.id,
    this.isLoading = false,
    this.imageBytes,
    this.reasoning,
  });

  final MessageAuthor author;
  final String text;
  final String id;
  final bool isLoading;

  /// 用户消息附带的截图（如有）。
  final Uint8List? imageBytes;

  /// AI 消息附带的流式推理过程（如有）。
  final String? reasoning;
}
