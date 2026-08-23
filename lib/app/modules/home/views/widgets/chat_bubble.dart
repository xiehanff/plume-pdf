import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:loading_indicator/loading_indicator.dart';

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
        crossAxisAlignment: isHuman
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
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
            child: isHuman ? _buildHumanContent() : _buildAiContent(),
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
            width: 20,
            height: 20,
            child: LoadingIndicator(
              indicatorType: Indicator.ballPulse,
              colors: <Color>[Color(0xB3FFFFFF)],
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
          constraints: const BoxConstraints(maxWidth: 160, maxHeight: 160),
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
    final String reasoning = message.reasoning?.trim() ?? '';
    final String text = message.text.trim();
    final List<Widget> children = <Widget>[];
    if (reasoning.isNotEmpty) {
      children.add(
        ReasoningPanel(text: reasoning, isLoading: message.isLoading),
      );
    }
    if (text.isNotEmpty) {
      children.add(_buildAiMarkdown());
    } else if (message.isLoading && reasoning.isEmpty) {
      children.add(_buildLoading());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildAiMarkdown() {
    return GptMarkdown(
      message.text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        height: 2.0,
        // 显式声明主工程中文字体，避免 gpt_markdown 本地包
        // 在某些边界场景下回退到系统默认字体而非 OPPO Sans。
        fontFamily: 'OPPO Sans',
        fontFamilyFallback: <String>[
          'Microsoft YaHei',
          'Microsoft YaHei UI',
          '微软雅黑',
        ],
      ),
      codeBuilder:
          (BuildContext context, String name, String code, bool closed) {
            final String language = name.isNotEmpty ? name : 'plaintext';
            return CodeBlock(language: language, code: code);
          },
      highlightBuilder: (BuildContext context, String text, TextStyle style) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.accentSurface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: style.copyWith(
              // 行内代码块高度收紧：否则继承正文 height 2.0 会撑破
              // WidgetSpan 行高计算，导致相邻行粘连。
              height: 1.2,
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

/// 流式推理过程的独立深色容器。
///
/// 默认只展示最多八行；内容超出后必须由用户点击按钮展开，避免复杂
/// 思考时侧栏只剩一个 loading 占位，也避免推理文本撑满整个对话区。
class ReasoningPanel extends StatefulWidget {
  const ReasoningPanel({super.key, required this.text, this.isLoading = false});

  final String text;
  final bool isLoading;

  @override
  State<ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<ReasoningPanel> {
  static const int _maxLines = 8;
  static const TextStyle _textStyle = TextStyle(
    color: Color(0xFFD0D5DD),
    fontSize: 12,
    height: 1.5,
  );

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxTextWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - 24).clamp(1, double.infinity)
            : 640;
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: _textStyle),
          textDirection: Directionality.of(context),
          maxLines: _maxLines,
          ellipsis: '…',
        )..layout(maxWidth: maxTextWidth);
        final bool hasOverflow = painter.didExceedMaxLines;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
          decoration: BoxDecoration(
            color: const Color(0xFF20242B),
            border: Border.all(color: const Color(0xFF343A46)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.psychology_outlined,
                    size: 15,
                    color: Color(0xFF98A2B3),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '思考过程',
                    style: TextStyle(
                      color: Color(0xFFB8C0CC),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.isLoading) ...<Widget>[
                    const SizedBox(width: 8),
                    const Text(
                      '思考中…',
                      style: TextStyle(color: Color(0xFF7F8998), fontSize: 11),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.text,
                style: _textStyle,
                maxLines: _expanded ? null : _maxLines,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              if (hasOverflow) ...<Widget>[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF98B8FF),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_expanded ? '收起' : '展开全部'),
                  ),
                ),
              ],
            ],
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
    final String hlLang =
        _langMap[language.toLowerCase()] ?? language.toLowerCase();
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
