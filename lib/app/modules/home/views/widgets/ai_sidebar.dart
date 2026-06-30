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
    required this.onSiliconFlowApiKeyChanged,
    required this.onSaveApiKey,
    required this.onSaveSiliconFlowApiKey,
    required this.onProviderChanged,
    required this.onSendChat,
    this.documentPath,
    this.leftSidebarWidth = 0,
  });

  final PdfAiPanelState state;
  final ValueChanged<String> onApiKeyChanged;
  final ValueChanged<String> onSiliconFlowApiKeyChanged;
  final Future<void> Function() onSaveApiKey;
  final Future<void> Function() onSaveSiliconFlowApiKey;
  final ValueChanged<AiProvider> onProviderChanged;
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

  late final TextEditingController _deepSeekController;
  late final TextEditingController _siliconFlowController;
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  late final FocusNode _inputFocusNode;
  bool _showSettings = false;
  double _sidebarWidth = 320;

  final List<ChatMessage> _messages = <ChatMessage>[];
  String? _lastActionLabel;
  int? _lastActionId;
  String? _lastResult;
  int _idCounter = 0;
  bool _needsPostFrameSync = false;

  @override
  void initState() {
    super.initState();
    _deepSeekController = TextEditingController(text: widget.state.apiKey);
    _siliconFlowController = TextEditingController(text: widget.state.siliconFlowApiKey);
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
    if (oldWidget.state.siliconFlowApiKey != widget.state.siliconFlowApiKey &&
        _siliconFlowController.text != widget.state.siliconFlowApiKey) {
      _siliconFlowController.text = widget.state.siliconFlowApiKey;
    }
    if (oldWidget.state.sessionId != widget.state.sessionId ||
        oldWidget.documentPath != widget.documentPath) {
      _resetConversation();
    }
  }

  @override
  void dispose() {
    _deepSeekController.dispose();
    _siliconFlowController.dispose();
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
                    siliconFlowController: _siliconFlowController,
                    selectedProvider: widget.state.selectedProvider,
                    onDeepSeekChanged: widget.onApiKeyChanged,
                    onSiliconFlowChanged: widget.onSiliconFlowApiKeyChanged,
                    onProviderChanged: widget.onProviderChanged,
                    onSaveDeepSeek: widget.onSaveApiKey,
                    onSaveSiliconFlow: widget.onSaveSiliconFlowApiKey,
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
      itemCount: _messages.length,
      itemBuilder: (BuildContext context, int index) {
        return ChatBubble(message: _messages[index]);
      },
    );
  }

  Future<void> _handleSend() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();

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
      _lastActionLabel = state.actionLabel;
      _lastActionId = state.actionId;
      _messages.add(ChatMessage(
        author: MessageAuthor.human,
        text: _lastActionLabel!,
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
      _lastResult = state.result;
      _replaceLoadingOrAdd(
        author: MessageAuthor.ai,
        text: _lastResult!,
      );
    }
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
      _messages.add(ChatMessage(
        author: author,
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
    _lastActionLabel = null;
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
