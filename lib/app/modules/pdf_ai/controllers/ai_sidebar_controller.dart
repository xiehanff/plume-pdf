import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:get/get.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart';

import '../models/pdf_ai_panel_state.dart';

typedef SendChatCallback = Future<void> Function(AiChatInput input);

enum AiSidebarMode { conversation, settings }

enum _ScrollFollowState { followingTail, userControlled }

/// Plume's PDF-AI panel controller.
///
/// Generic conversation state/presentation is owned by [AiChatController]. This
/// controller keeps only host concerns: sidebar geometry, API-key settings,
/// input/focus objects and the user's scroll-follow preference.
class AiSidebarController extends GetxController {
  static const String tag = 'ai-sidebar';

  static const double _kMinWidth = 240;
  static const double _kMinPdfAreaWidth = 200;
  static const double _kBottomFollowThreshold = 80;

  AiSidebarController({
    required PdfAiPanelState state,
    required AiChatController chatController,
    required ValueChanged<String> onApiKeyChanged,
    required Future<void> Function() onSaveApiKey,
    required SendChatCallback onSendChat,
    required VoidCallback onStopChat,
    required VoidCallback onNewSession,
    String? documentPath,
    double leftSidebarWidth = 0,
  }) : _panelState = state,
       _chatController = chatController,
       _documentPath = documentPath,
       _leftSidebarWidth = leftSidebarWidth,
       _onApiKeyChanged = onApiKeyChanged,
       _onSaveApiKey = onSaveApiKey,
       _onSendChat = onSendChat,
       _onStopChat = onStopChat,
       _onNewSession = onNewSession {
    _deepSeekController = TextEditingController(text: state.apiKey);
    _inputController = TextEditingController();
    _scrollController = FollowTailScrollController(
      isFollowingTail: () =>
          _scrollFollowState == _ScrollFollowState.followingTail,
    );
    _inputFocusNode = FocusNode();
    _lastMessageCount = chatController.messages.length;
    _removeChatListener = chatController.addListenerId(
      AiChatUpdateId.messages,
      _handleChatControllerChanged,
    );
  }

  late final TextEditingController _deepSeekController;
  late final TextEditingController _inputController;
  late final FollowTailScrollController _scrollController;
  late final FocusNode _inputFocusNode;

  PdfAiPanelState _panelState;
  final AiChatController _chatController;
  String? _documentPath;
  double _leftSidebarWidth;
  final ValueChanged<String> _onApiKeyChanged;
  final Future<void> Function() _onSaveApiKey;
  final SendChatCallback _onSendChat;
  final VoidCallback _onStopChat;
  final VoidCallback _onNewSession;
  VoidCallback? _removeChatListener;

  AiSidebarMode _mode = AiSidebarMode.conversation;
  double _sidebarWidth = 320;

  _ScrollFollowState _scrollFollowState = _ScrollFollowState.followingTail;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;
  int _scrollRequestId = 0;
  bool _hasDeferredStreamingUpdate = false;
  int _lastMessageCount = 0;

  PdfAiPanelState get state => _panelState;
  AiSidebarMode get mode => _mode;
  bool get isLoading => _panelState.loading || _chatController.isGenerating;

  bool get showFollowUpSuggestions {
    if (isLoading || followUpSuggestions.isEmpty || messages.isEmpty) {
      return false;
    }
    final ChatMessage last = messages.last;
    return last.author == MessageAuthor.ai &&
        !last.isLoading &&
        last.text.trim().isNotEmpty &&
        !last.text.startsWith('❌');
  }

  List<ChatMessage> get messages => _chatController.messages;
  List<String> get followUpSuggestions =>
      _chatController.followUpSuggestions;
  TextEditingController get deepSeekController => _deepSeekController;
  TextEditingController get inputController => _inputController;
  ScrollController get scrollController => _scrollController;
  FocusNode get inputFocusNode => _inputFocusNode;
  double get sidebarWidth => _sidebarWidth;
  ValueChanged<String> get onApiKeyChanged => _onApiKeyChanged;
  Future<void> Function() get onSaveApiKey => _onSaveApiKey;
  VoidCallback get onNewSession => _handleNewSession;
  VoidCallback get onStopChat => _onStopChat;

  void updateExternalState({
    required PdfAiPanelState state,
    required String? documentPath,
    required double leftSidebarWidth,
  }) {
    final bool documentChanged = _documentPath != documentPath;
    final bool apiKeyChanged = _panelState.apiKey != state.apiKey;
    final bool preflightLoadingChanged = _panelState.loading != state.loading;
    final bool geometryChanged = _leftSidebarWidth != leftSidebarWidth;

    _panelState = state;
    _documentPath = documentPath;
    _leftSidebarWidth = leftSidebarWidth;

    if (documentChanged) {
      _resetHostConversationUi();
    }
    if (apiKeyChanged && _deepSeekController.text != state.apiKey) {
      _deepSeekController.text = state.apiKey;
    }

    if (documentChanged ||
        apiKeyChanged ||
        preflightLoadingChanged ||
        geometryChanged) {
      update();
    }
  }

  void showSettings() {
    _mode = AiSidebarMode.settings;
    update();
  }

  void showConversation() {
    _mode = AiSidebarMode.conversation;
    update();
  }

  void _markUserScrolled() {
    if (_scrollFollowState == _ScrollFollowState.userControlled) return;
    _scrollFollowState = _ScrollFollowState.userControlled;
    _scrollRequestId++;
  }

  void _resumeScrollFollowing() {
    _scrollFollowState = _ScrollFollowState.followingTail;
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    bool resumedFollowing = false;
    if (notification is UserScrollNotification) {
      _userScrollDirection = notification.direction;
      if (notification.direction == ScrollDirection.idle) return false;

      _markUserScrolled();
      if (notification.direction == ScrollDirection.reverse &&
          notification.metrics.extentAfter <= _kBottomFollowThreshold) {
        _resumeScrollFollowing();
        resumedFollowing = true;
      }
    } else if (notification is ScrollUpdateNotification &&
        _userScrollDirection == ScrollDirection.reverse &&
        notification.metrics.extentAfter <= _kBottomFollowThreshold) {
      _resumeScrollFollowing();
      resumedFollowing = true;
    }

    if (resumedFollowing) {
      _flushDeferredStreamingUpdate();
      _scheduleScrollToBottom();
    }
    return false;
  }

  void handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) return;
    final double delta = event.scrollDelta.dy;
    final ScrollPosition position = _scrollController.position;
    if (delta == 0 ||
        (delta < 0 && position.pixels <= position.minScrollExtent) ||
        (delta > 0 && position.pixels >= position.maxScrollExtent)) {
      return;
    }
    _markUserScrolled();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients ||
        _scrollFollowState != _ScrollFollowState.followingTail) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _scheduleScrollToBottom() {
    final int requestId = _scrollRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isClosed && requestId == _scrollRequestId) _scrollToBottom();
    });
  }

  void _flushDeferredStreamingUpdate() {
    if (!_hasDeferredStreamingUpdate || isClosed) return;
    _hasDeferredStreamingUpdate = false;
    update();
  }

  void _handleChatControllerChanged() {
    if (isClosed) return;

    final int messageCount = messages.length;
    final bool messageCountChanged = messageCount != _lastMessageCount;
    final bool addedMessage = messageCount > _lastMessageCount;
    final bool resetConversation = messageCount == 0 && _lastMessageCount > 0;
    _lastMessageCount = messageCount;

    if (addedMessage) {
      _resumeScrollFollowing();
      _hasDeferredStreamingUpdate = false;
    } else if (resetConversation) {
      _resetHostConversationUi();
    }

    // Streaming markdown can be expensive. While the user is reading history,
    // keep the newest package state but defer rebuilding this sidebar until the
    // user returns to the bottom or the turn finishes/stops.
    if (_scrollFollowState == _ScrollFollowState.userControlled &&
        _chatController.isGenerating &&
        !messageCountChanged) {
      _hasDeferredStreamingUpdate = true;
      return;
    }

    _hasDeferredStreamingUpdate = false;
    update();
    if (addedMessage) {
      _scheduleScrollToBottom();
    }
  }

  Future<void> handleSend(AiChatInput input) async {
    if (input.isEmpty) return;
    await sendMessage(input.text, image: input.image);
  }

  Future<void> sendMessage(String text, {AiImageAttachment? image}) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty && (image?.bytes.isEmpty ?? true)) return;
    _resumeScrollFollowing();
    _hasDeferredStreamingUpdate = false;
    await _onSendChat(AiChatInput(text: trimmedText, image: image));
  }

  void _handleNewSession() {
    _resetHostConversationUi();
    _onNewSession();
  }

  void handleResize(DragUpdateDetails details, double screenWidth) {
    final double maxWidth = screenWidth - _leftSidebarWidth - _kMinPdfAreaWidth;
    if (maxWidth < _kMinWidth) return;
    _sidebarWidth = (_sidebarWidth - details.delta.dx)
        .clamp(_kMinWidth, maxWidth)
        .toDouble();
    update();
  }

  void _resetHostConversationUi() {
    _inputController.clear();
    _resumeScrollFollowing();
    _userScrollDirection = ScrollDirection.idle;
    _scrollRequestId++;
    _hasDeferredStreamingUpdate = false;
  }

  @override
  void onClose() {
    _removeChatListener?.call();
    _removeChatListener = null;
    _deepSeekController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.onClose();
  }
}
