import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../../theme/app_colors.dart';
import 'chat_message.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isHuman = message.author == MessageAuthor.human;

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isHuman ? 32 : 0,
        right: isHuman ? 0 : 32,
      ),
      child: Column(
        crossAxisAlignment:
            isHuman ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isHuman ? AppColors.accentSurface : AppColors.surfaceBg,
              borderRadius: isHuman
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                      topRight: Radius.zero,
                    )
                  : BorderRadius.circular(12),
            ),
            child: message.isLoading
                ? _buildLoading()
                : isHuman
                    ? _buildHumanContent()
                    : _buildAiContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '思考中…',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumanContent() {
    final Widget text = Text(
      message.text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        height: 2.0,
      ),
    );
    final Uint8List? imageBytes = message.imageBytes;
    if (imageBytes == null || imageBytes.isEmpty) {
      return text;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 160,
            maxHeight: 160,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
        if (message.text.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          text,
        ],
      ],
    );
  }

  Widget _buildAiContent() {
    return GptMarkdown(
      message.text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        height: 2.0,
      ),
      codeBuilder: (BuildContext context, String name, String code, bool closed) {
        final String language = name.isNotEmpty ? name : 'plaintext';
        return CodeBlock(language: language, code: code);
      },
      highlightBuilder: (BuildContext context, String text, TextStyle style) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentSurface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: style.copyWith(
              fontFamily: 'JetBrainsMono',
              package: 'gpt_markdown',
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}

class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.language, required this.code});

  final String language;
  final String code;

  static const Map<String, String> _langMap = <String, String>{
    'dart': 'dart',
    'python': 'python',
    'py': 'python',
    'javascript': 'javascript',
    'js': 'javascript',
    'typescript': 'typescript',
    'ts': 'typescript',
    'java': 'java',
    'kotlin': 'kotlin',
    'swift': 'swift',
    'c': 'c',
    'cpp': 'cpp',
    'c++': 'cpp',
    'go': 'go',
    'rust': 'rust',
    'ruby': 'ruby',
    'php': 'php',
    'shell': 'bash',
    'bash': 'bash',
    'sh': 'bash',
    'sql': 'sql',
    'yaml': 'yaml',
    'yml': 'yaml',
    'json': 'json',
    'xml': 'xml',
    'html': 'xml',
    'css': 'css',
    'markdown': 'markdown',
    'md': 'markdown',
  };

  @override
  Widget build(BuildContext context) {
    final String hlLang = _langMap[language.toLowerCase()] ?? language.toLowerCase();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF282C34),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF21252B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Text(
              language,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: HighlightView(
              code,
              language: hlLang,
              theme: atomOneDarkTheme,
              textStyle: const TextStyle(
                fontSize: 13,
                height: 1.5,
                fontFamily: 'JetBrainsMono',
                package: 'gpt_markdown',
                fontFamilyFallback: [
                  'Microsoft YaHei',
                  'Microsoft YaHei UI',
                  '微软雅黑',
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
