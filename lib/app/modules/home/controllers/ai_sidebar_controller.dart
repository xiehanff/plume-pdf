import 'dart:typed_data';

import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:get/get.dart';

import '../models/pdf_ai_panel_state.dart';
import '../views/widgets/chat_message.dart';

typedef SendChatCallback = Future<void> Function(String message);

enum AiSidebarMode { conversation, settings }

enum AiSidebarFollowUpState { hidden, visible }

enum _MessageLayoutState { clean, needsPostFrameSync }

enum _ScrollFollowState { followingTail, userControlled }

enum _ResultUpdateMode { replace, incremental }

class _ConversationState {
  final List<ChatMessage> messages = <ChatMessage>[];
  _MessageLayoutState layoutState = _MessageLayoutState.needsPostFrameSync;
  int? lastActionId;
  String? lastResult;
  int _nextMessageId = 0;

  String nextMessageId() => 'msg_${_nextMessageId++}';

  void markLayoutNeedsSync() {
    layoutState = _MessageLayoutState.needsPostFrameSync;
  }

  void reset() {
    messages.clear();
    layoutState = _MessageLayoutState.clean;
    lastActionId = null;
    lastResult = null;
  }
}

class AiSidebarController extends GetxController {
  /// 在 GetX 容器中的注册键。由 `HomeController` 负责创建与同步，
  /// 侧栏开关期间实例常驻，会话历史不会因收起侧栏而丢失。
  static const String tag = 'ai-sidebar';

  static const double _kMinWidth = 240;
  static const double _kMinPdfAreaWidth = 200;
  static const double _kBottomFollowThreshold = 80;

  AiSidebarController({
    required PdfAiPanelState state,
    required ValueChanged<String> onApiKeyChanged,
    required Future<void> Function() onSaveApiKey,
    required SendChatCallback onSendChat,
    required VoidCallback onNewSession,
    String? documentPath,
    double leftSidebarWidth = 0,
  }) : _panelState = state,
       _documentPath = documentPath,
       _leftSidebarWidth = leftSidebarWidth,
       _onApiKeyChanged = onApiKeyChanged,
       _onSaveApiKey = onSaveApiKey,
       _onSendChat = onSendChat,
       _onNewSession = onNewSession {
    _deepSeekController = TextEditingController(text: state.apiKey);
    _inputController = TextEditingController();
    _scrollController = ScrollController();
    _inputFocusNode = FocusNode();
    _syncConversationWithPanelState();
  }

  late final TextEditingController _deepSeekController;
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  late final FocusNode _inputFocusNode;

  PdfAiPanelState _panelState;
  String? _documentPath;
  double _leftSidebarWidth;
  ValueChanged<String> _onApiKeyChanged;
  Future<void> Function() _onSaveApiKey;
  SendChatCallback _onSendChat;
  VoidCallback _onNewSession;

  AiSidebarMode _mode = AiSidebarMode.conversation;
  double _sidebarWidth = 320;
  final _ConversationState _conversation = _ConversationState();

  _ScrollFollowState _scrollFollowState = _ScrollFollowState.followingTail;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;
  int _scrollRequestId = 0;

  PdfAiPanelState get state => _panelState;

  AiSidebarMode get mode => _mode;

  AiSidebarFollowUpState get followUpState {
    if (_panelState.loading ||
        _panelState.errorMessage != null ||
        _panelState.followUpSuggestions.isEmpty) {
      return AiSidebarFollowUpState.hidden;
    }
    if (_conversation.messages.isEmpty) {
      return AiSidebarFollowUpState.hidden;
    }
    final ChatMessage last = _conversation.messages.last;
    if (last.author != MessageAuthor.ai ||
        last.isLoading ||
        last.text.trim().isEmpty ||
        last.text.startsWith('❌')) {
      return AiSidebarFollowUpState.hidden;
    }
    return AiSidebarFollowUpState.visible;
  }

  List<ChatMessage> get messages => _conversation.messages;

  List<String> get followUpSuggestions => _panelState.followUpSuggestions;

  TextEditingController get deepSeekController => _deepSeekController;

  TextEditingController get inputController => _inputController;

  ScrollController get scrollController => _scrollController;

  FocusNode get inputFocusNode => _inputFocusNode;

  double get sidebarWidth => _sidebarWidth;

  ValueChanged<String> get onApiKeyChanged => _onApiKeyChanged;

  Future<void> Function() get onSaveApiKey => _onSaveApiKey;

  VoidCallback get onNewSession => _onNewSession;

  /// 接收父组件的新面板状态，并同步控制器内部的会话状态。
  void updateExternalState({
    required PdfAiPanelState state,
    required String? documentPath,
    required double leftSidebarWidth,
    required ValueChanged<String> onApiKeyChanged,
    required Future<void> Function() onSaveApiKey,
    required SendChatCallback onSendChat,
    required VoidCallback onNewSession,
  }) {
    final bool sessionChanged =
        _panelState.sessionId != state.sessionId ||
        _documentPath != documentPath;
    final bool apiKeyChanged = _panelState.apiKey != state.apiKey;

    _panelState = state;
    _documentPath = documentPath;
    _leftSidebarWidth = leftSidebarWidth;
    _onApiKeyChanged = onApiKeyChanged;
    _onSaveApiKey = onSaveApiKey;
    _onSendChat = onSendChat;
    _onNewSession = onNewSession;

    if (sessionChanged) {
      _resetConversation(notify: false);
    }
    if (apiKeyChanged && _deepSeekController.text != state.apiKey) {
      _deepSeekController.text = state.apiKey;
    }

    _syncConversationWithPanelState();
    update();
  }

  void showSettings() {
    _mode = AiSidebarMode.settings;
    update();
  }

  void showConversation() {
    _mode = AiSidebarMode.conversation;
    update();
  }

  /// 用户开始滚动后，立即取消已排队的自动跟随请求。
  void _markUserScrolled() {
    if (_scrollFollowState == _ScrollFollowState.userControlled) {
      return;
    }
    _scrollFollowState = _ScrollFollowState.userControlled;
    _scrollRequestId++;
  }

  void _resumeScrollFollowing() {
    _scrollFollowState = _ScrollFollowState.followingTail;
  }

  /// 处理 ListView 滚动通知。
  ///
  /// 不能在 ScrollEndNotification 中仅按距离恢复跟随：鼠标滚轮的每个
  /// PointerScrollEvent 都会同步产生 ScrollEndNotification，从底部附近
  /// 上滚时会因此立刻重新开启自动跟随。只有用户向底部滚动并进入阈值，
  /// 才恢复跟随。
  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is UserScrollNotification) {
      _userScrollDirection = notification.direction;
      if (notification.direction == ScrollDirection.idle) {
        return false;
      }

      _markUserScrolled();
      if (notification.direction == ScrollDirection.reverse &&
          notification.metrics.extentAfter <= _kBottomFollowThreshold) {
        _resumeScrollFollowing();
      }
    } else if (notification is ScrollUpdateNotification &&
        _userScrollDirection == ScrollDirection.reverse &&
        notification.metrics.extentAfter <= _kBottomFollowThreshold) {
      // UserScrollNotification 只在方向变化时发送；持续向下滚动时，
      // 需要在后续更新中捕获进入底部阈值的时刻。
      _resumeScrollFollowing();
    }
    return false;
  }

  /// 在 Scrollable 处理鼠标滚轮之前取消自动跟随，避免同一帧中已经排队
  /// 的 post-frame 回调抢先把用户刚开始的滚动跳回底部。
  void handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) {
      return;
    }
    final double delta = event.scrollDelta.dy;
    final ScrollPosition position = _scrollController.position;
    if (delta == 0 ||
        (delta < 0 && position.pixels <= position.minScrollExtent) ||
        (delta > 0 && position.pixels >= position.maxScrollExtent)) {
      return;
    }
    _markUserScrolled();
  }

  /// 仅当用户仍在跟随尾部时滚动到底部，避免打断用户阅读。
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    if (_scrollFollowState != _ScrollFollowState.followingTail) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  /// 下一帧滚动到底部（仅在用户已停留底部时生效）。
  void _scheduleScrollToBottom() {
    final int requestId = _scrollRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed && requestId == _scrollRequestId) {
        _scrollToBottom();
      }
    });
  }

  Future<void> handleSend() async {
    final String text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    await sendMessage(text);
  }

  Future<void> sendMessage(String text) async {
    _conversation.messages.add(
      ChatMessage(
        author: MessageAuthor.human,
        text: text,
        id: _conversation.nextMessageId(),
      ),
    );
    _conversation.markLayoutNeedsSync();
    _ensureLoadingPlaceholder();
    _resumeScrollFollowing();
    update();
    // 流式首个 chunk 直接 jumpTo 跟随，避免动画被后续更新打断。
    _scheduleScrollToBottom();
    await _onSendChat(text);
  }

  void handleResize(DragUpdateDetails details, double screenWidth) {
    final double maxWidth = screenWidth - _leftSidebarWidth - _kMinPdfAreaWidth;
    if (maxWidth < _kMinWidth) return;
    _sidebarWidth = (_sidebarWidth - details.delta.dx)
        .clamp(_kMinWidth, maxWidth)
        .toDouble();
    update();
  }

  void _syncConversationWithPanelState() {
    _syncAction(_panelState);

    if (_panelState.loading && _conversation.lastResult == null) {
      _ensureLoadingPlaceholder();
      _scheduleScrollToBottom();
    }

    if (_panelState.errorMessage != null &&
        _panelState.errorMessage != _conversation.lastResult) {
      _conversation.lastResult = _panelState.errorMessage;
      _replaceLoadingOrAdd(
        author: MessageAuthor.ai,
        text: '❌ ${_panelState.errorMessage}',
      );
      return;
    }

    if (_panelState.result != null &&
        _panelState.result != _conversation.lastResult &&
        _panelState.result!.trim().isNotEmpty) {
      _syncResult(_panelState.result!);
    }
  }

  void _syncAction(PdfAiPanelState state) {
    if (state.actionLabel == null ||
        state.actionId == _conversation.lastActionId) {
      return;
    }

    _conversation.lastActionId = state.actionId;
    _conversation.lastResult = null;
    _conversation.messages.add(
      ChatMessage(
        author: MessageAuthor.human,
        text: _buildActionUserText(state),
        imageBytes: state.actionSelectionImage,
        id: _conversation.nextMessageId(),
      ),
    );
    _conversation.markLayoutNeedsSync();
    _resumeScrollFollowing();
    // 动作触发后流式输出立即开始，直接 jumpTo 跟随尾部。
    _scheduleScrollToBottom();
  }

  void _syncResult(String result) {
    final _ResultUpdateMode updateMode = _resultUpdateMode(result);
    _conversation.lastResult = result;
    switch (updateMode) {
      case _ResultUpdateMode.replace:
        _replaceLoadingOrAdd(author: MessageAuthor.ai, text: result);
      case _ResultUpdateMode.incremental:
        _updateLastAiMessage(result);
        _scheduleScrollToBottom();
    }
  }

  _ResultUpdateMode _resultUpdateMode(String result) {
    final String? previousResult = _conversation.lastResult;
    if (previousResult != null &&
        result.length > previousResult.length &&
        result.startsWith(previousResult)) {
      return _ResultUpdateMode.incremental;
    }
    return _ResultUpdateMode.replace;
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
    final String singleLine = selectionText
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final String shortened = singleLine.length <= 80
        ? singleLine
        : '${singleLine.substring(0, 80)}…';
    return '$label $shortened';
  }

  void _ensureLoadingPlaceholder() {
    final int loadingIndex = _conversation.messages.indexWhere(
      (ChatMessage message) =>
          message.author == MessageAuthor.ai && message.isLoading,
    );
    if (loadingIndex >= 0) {
      return;
    }
    _conversation.messages.add(
      ChatMessage(
        author: MessageAuthor.ai,
        text: '',
        id: _conversation.nextMessageId(),
        isLoading: true,
      ),
    );
    _conversation.markLayoutNeedsSync();
    _scheduleMessageLayoutSync();
  }

  void _replaceLoadingOrAdd({
    required MessageAuthor author,
    required String text,
  }) {
    final int loadingIndex = _conversation.messages.indexWhere(
      (ChatMessage message) =>
          message.author == MessageAuthor.ai && message.isLoading,
    );
    if (loadingIndex >= 0) {
      final ChatMessage loadingMessage = _conversation.messages[loadingIndex];
      _conversation.messages[loadingIndex] = ChatMessage(
        author: author,
        text: text,
        id: loadingMessage.id,
        isLoading: false,
      );
    } else {
      _updateLastAiMessage(text);
    }
    _conversation.markLayoutNeedsSync();
    _scheduleMessageLayoutSync();
    _scheduleScrollToBottom();
  }

  /// 更新最后一条 AI 消息内容（流式增量或替换）；不存在则新增。
  /// 仅负责消息更新，滚动调度由调用方控制。
  void _updateLastAiMessage(String text) {
    final int lastIndex = _conversation.messages.length - 1;
    if (lastIndex >= 0 &&
        _conversation.messages[lastIndex].author == MessageAuthor.ai) {
      final ChatMessage previousMessage = _conversation.messages[lastIndex];
      _conversation.messages[lastIndex] = ChatMessage(
        author: MessageAuthor.ai,
        text: text,
        id: previousMessage.id,
      );
    } else {
      _conversation.messages.add(
        ChatMessage(
          author: MessageAuthor.ai,
          text: text,
          id: _conversation.nextMessageId(),
        ),
      );
    }
    _conversation.markLayoutNeedsSync();
    _scheduleMessageLayoutSync();
  }

  void _scheduleMessageLayoutSync() {
    if (_conversation.layoutState != _MessageLayoutState.needsPostFrameSync ||
        _conversation.messages.isEmpty) {
      return;
    }
    _conversation.layoutState = _MessageLayoutState.clean;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) {
        update();
      }
    });
  }

  void _resetConversation({required bool notify}) {
    _conversation.reset();
    _inputController.clear();
    _resumeScrollFollowing();
    _userScrollDirection = ScrollDirection.idle;
    _scrollRequestId++;
    if (notify) {
      update();
    }
  }

  @override
  void onClose() {
    _deepSeekController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.onClose();
  }
}
