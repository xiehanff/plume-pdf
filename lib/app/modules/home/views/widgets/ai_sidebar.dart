import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/pdf_ai_panel_state.dart';
import '../../../../theme/app_colors.dart';
import 'ai_sidebar_settings.dart';
import 'chat_bubble.dart';
import 'chat_input_bar.dart';
import 'chat_message.dart';

typedef SendChatCallback = Future<void> Function(String message);

class AiSidebar extends StatefulWidget {
  const AiSidebar({
    super.key,
    required this.state,
    required this.onApiKeyChanged,
    required this.onSaveApiKey,
    required this.onSendChat,
    this.documentPath,
    this.leftSidebarWidth = 0,
  });

  final PdfAiPanelState state;
  final ValueChanged<String> onApiKeyChanged;
  final Future<void> Function() onSaveApiKey;
  final SendChatCallback onSendChat;
  final String? documentPath;
  final double leftSidebarWidth;

  @override
  State<AiSidebar> createState() => _AiSidebarState();
}



class _AiSidebarState extends State<AiSidebar> {
  static const double _kMinWidth = 240;
  static const double _kHandleWidth = 6;
  static const double _kMinPdfAreaWidth = 200;

  static const List<String> _followUpSuggestions = <String>[
    '再详细解释一下',
    '用更简单的语言说明',
    '总结为要点',
    '举一个例子',
    '文中还有哪些重点？',
  ];

  late final TextEditingController _deepSeekController;
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  late final FocusNode _inputFocusNode;
  bool _showSettings = false;
  double _sidebarWidth = 320;

  final List<ChatMessage> _messages = <ChatMessage>[];
  int? _lastActionId;
  String? _lastResult;
  int _idCounter = 0;
  bool _needsPostFrameSync = false;

  @override
  void initState() {
    super.initState();
    _deepSeekController = TextEditingController(text: widget.state.apiKey);
    _inputController = TextEditingController();
    _scrollController = ScrollController();
    _inputFocusNode = FocusNode();
    _needsPostFrameSync = true;
  }

  @override
  void didUpdateWidget(covariant AiSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.apiKey != widget.state.apiKey &&
        _deepSeekController.text != widget.state.apiKey) {
      _deepSeekController.text = widget.state.apiKey;
    }
    if (oldWidget.state.sessionId != widget.state.sessionId ||
        oldWidget.documentPath != widget.documentPath) {
      _resetConversation();
    }
  }

  @override
  void dispose() {
    _deepSeekController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _handleResize,
          child: const MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: SizedBox(
              width: _kHandleWidth,
              height: double.infinity,
            ),
          ),
        ),
        Container(
          width: _sidebarWidth,
          color: AppColors.scaffoldBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_showSettings)
                AiSidebarSettingsHeader(
                    onBack: () => setState(() => _showSettings = false)),
              if (_showSettings)
                Expanded(
                  child: AiSidebarSettingsList(
                    deepSeekController: _deepSeekController,
                    onDeepSeekChanged: widget.onApiKeyChanged,
                    onSaveDeepSeek: widget.onSaveApiKey,
                  ),
                )
              else ...<Widget>[
                Expanded(
                  child: _buildMessageList(),
                ),
                ChatInputBar(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  isLoading: widget.state.loading,
                  onSend: _handleSend,
                  onSettingsTap: () => setState(() => _showSettings = true),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    _syncMessagesFromState();

    if (_needsPostFrameSync && _messages.isNotEmpty) {
      _needsPostFrameSync = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '框选后点击工具条里的"翻译"或"解释"，\n或在下方输入框追问',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      itemCount: _messages.length + (_showFollowUpSuggestions ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index == _messages.length) {
          return _FollowUpSuggestions(onTap: _sendMessage);
        }
        return ChatBubble(message: _messages[index]);
      },
    );
  }

  /// 模型回复完成后展示追问建议。
  bool get _showFollowUpSuggestions {
    final PdfAiPanelState state = widget.state;
    if (state.loading || state.errorMessage != null) {
      return false;
    }
    if (_messages.isEmpty) {
      return false;
    }
    final ChatMessage last = _messages.last;
    if (last.author != MessageAuthor.ai ||
        last.isLoading ||
        last.text.trim().isEmpty ||
        last.text.startsWith('❌')) {
      return false;
    }
    return true;
  }

  Future<void> _handleSend() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    await _sendMessage(text);
  }

  Future<void> _sendMessage(String text) async {
    _messages.add(ChatMessage(
      author: MessageAuthor.human,
      text: text,
      id: 'msg_${_idCounter++}',
    ));
    _ensureLoadingPlaceholder();
    setState(() {});
    await widget.onSendChat(text);
  }

  void _syncMessagesFromState() {
    final PdfAiPanelState state = widget.state;

    if (state.actionLabel != null &&
        state.actionId != _lastActionId) {
      _lastActionId = state.actionId;
      _lastResult = null;
      _messages.add(ChatMessage(
        author: MessageAuthor.human,
        text: _buildActionUserText(state),
        imageBytes: state.actionSelectionImage,
        id: 'msg_${_idCounter++}',
      ));
      _needsPostFrameSync = true;
    }

    if (state.loading && _lastResult == null) {
      _ensureLoadingPlaceholder();
    }

    if (state.errorMessage != null &&
        state.errorMessage != _lastResult) {
      _lastResult = state.errorMessage;
      _replaceLoadingOrAdd(
        author: MessageAuthor.ai,
        text: '❌ ${state.errorMessage}',
      );
      return;
    }

    if (state.result != null &&
        state.result != _lastResult &&
        state.result!.trim().isNotEmpty) {
      final String newResult = state.result!;
      final bool isIncremental =
          _lastResult != null &&
          newResult.length > _lastResult!.length &&
          newResult.startsWith(_lastResult!);
      _lastResult = newResult;
      if (isIncremental) {
        _updateLastAiMessage(newResult);
      } else {
        _replaceLoadingOrAdd(
          author: MessageAuthor.ai,
          text: newResult,
        );
      }
    }
  }

  /// 构建动作轮次的用户气泡文本：如 "翻译 xxx" / "解释 xxx"。
  /// 带选区截图时返回空串，仅展示图片。
  String _buildActionUserText(PdfAiPanelState state) {
    final Uint8List? image = state.actionSelectionImage;
    if (image != null && image.isNotEmpty) {
      return '';
    }
    final String label = state.actionLabel ?? '';
    final String selectionText = state.actionSelectionText ?? '';
    if (selectionText.trim().isEmpty) {
      return label;
    }
    final String singleLine =
        selectionText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final String shortened = singleLine.length <= 80
        ? singleLine
        : '${singleLine.substring(0, 80)}…';
    return '$label $shortened';
  }

  void _ensureLoadingPlaceholder() {
    final bool hasLoading = _messages.any(
        (ChatMessage m) => m.author == MessageAuthor.ai && m.isLoading);
    if (!hasLoading) {
      _messages.add(ChatMessage(
        author: MessageAuthor.ai,
        text: '',
        id: 'msg_${_idCounter++}',
        isLoading: true,
      ));
    }
  }

  void _replaceLoadingOrAdd({
    required MessageAuthor author,
    required String text,
  }) {
    final int loadingIndex = _messages.indexWhere(
        (ChatMessage m) => m.author == MessageAuthor.ai && m.isLoading);
    if (loadingIndex >= 0) {
      _messages[loadingIndex] = ChatMessage(
        author: author,
        text: text,
        id: _messages[loadingIndex].id,
        isLoading: false,
      );
    } else {
      _updateLastAiMessage(text);
    }
    _needsPostFrameSync = true;
  }

  /// 更新最后一条 AI 消息内容（流式增量或替换）；不存在则新增。
  void _updateLastAiMessage(String text) {
    final int lastIndex = _messages.length - 1;
    if (lastIndex >= 0 &&
        _messages[lastIndex].author == MessageAuthor.ai) {
      _messages[lastIndex] = ChatMessage(
        author: MessageAuthor.ai,
        text: text,
        id: _messages[lastIndex].id,
      );
    } else {
      _messages.add(ChatMessage(
        author: MessageAuthor.ai,
        text: text,
        id: 'msg_${_idCounter++}',
      ));
    }
    _needsPostFrameSync = true;
  }

  double get _maxWidth {
    final double screenWidth = MediaQuery.of(context).size.width;
    return screenWidth - widget.leftSidebarWidth - _kMinPdfAreaWidth;
  }

  void _resetConversation() {
    _messages.clear();
    _lastActionId = null;
    _lastResult = null;
    _inputController.clear();
    _needsPostFrameSync = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _handleResize(DragUpdateDetails details) {
    final double maxW = _maxWidth;
    if (maxW < _kMinWidth) return;
    setState(() {
      _sidebarWidth =
          (_sidebarWidth - details.delta.dx).clamp(_kMinWidth, maxW);
    });
  }
}

/// 模型回复完成后展示的追问建议（Wrap 组件）。
class _FollowUpSuggestions extends StatelessWidget {
  const _FollowUpSuggestions({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final String text in _AiSidebarState._followUpSuggestions)
            ActionChip(
              label: Text(
                text,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              onPressed: () => onTap(text),
              backgroundColor: AppColors.fillSubtle,
              side: const BorderSide(color: AppColors.borderSoft),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
