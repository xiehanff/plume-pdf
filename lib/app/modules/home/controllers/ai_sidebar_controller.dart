import 'dart:typed_data';

import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:get/get.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart'
    show AiConversationPresenter, FollowTailScrollController;

import '../models/ai_chat_input.dart';
import '../models/pdf_ai_panel_state.dart';
import '../views/widgets/chat_message.dart';

typedef SendChatCallback = Future<void> Function(AiChatInput input);

enum AiSidebarMode { conversation, settings }

enum _ScrollFollowState { followingTail, userControlled }

class AiSidebarController extends GetxController {
  static const String tag = 'ai-sidebar';

  static const double _kMinWidth = 240;
  static const double _kMinPdfAreaWidth = 200;
  static const double _kBottomFollowThreshold = 80;

  AiSidebarController({
    required PdfAiPanelState state,
    required ValueChanged<String> onApiKeyChanged,
    required Future<void> Function() onSaveApiKey,
    required SendChatCallback onSendChat,
    required VoidCallback onStopChat,
    required VoidCallback onNewSession,
    String? documentPath,
    double leftSidebarWidth = 0,
  }) : _panelState = state,
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
    _syncConversationWithPanelState();
  }

  late final TextEditingController _deepSeekController;
  late final TextEditingController _inputController;
  late final FollowTailScrollController _scrollController;
  late final FocusNode _inputFocusNode;

  PdfAiPanelState _panelState;
  String? _documentPath;
  double _leftSidebarWidth;
  final ValueChanged<String> _onApiKeyChanged;
  final Future<void> Function() _onSaveApiKey;
  final SendChatCallback _onSendChat;
  final VoidCallback _onStopChat;
  final VoidCallback _onNewSession;

  AiSidebarMode _mode = AiSidebarMode.conversation;
  double _sidebarWidth = 320;
  final AiConversationPresenter _conversation = AiConversationPresenter();
  int? _lastActionId;

  _ScrollFollowState _scrollFollowState = _ScrollFollowState.followingTail;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;
  int _scrollRequestId = 0;
  bool _hasDeferredStreamingUpdate = false;

  PdfAiPanelState get state => _panelState;

  AiSidebarMode get mode => _mode;

  bool get showFollowUpSuggestions {
    if (_panelState.loading ||
        _panelState.errorMessage != null ||
        _panelState.followUpSuggestions.isEmpty ||
        _conversation.isEmpty) {
      return false;
    }
    final ChatMessage last = _conversation.messages.last;
    return last.author == MessageAuthor.ai &&
        !last.isLoading &&
        last.text.trim().isNotEmpty &&
        !last.text.startsWith('❌');
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

  VoidCallback get onStopChat => _onStopChat;

  /// 只同步真正会变化的外部数据。Controller 的行为回调在构造时固定，
  /// 不再随每个流式 preview 重复赋值。
  void updateExternalState({
    required PdfAiPanelState state,
    required String? documentPath,
    required double leftSidebarWidth,
  }) {
    final bool sessionChanged =
        _panelState.sessionId != state.sessionId ||
        _documentPath != documentPath;
    final bool startsNewRound =
        sessionChanged ||
        (state.actionId != null && state.actionId != _panelState.actionId);
    final bool apiKeyChanged = _panelState.apiKey != state.apiKey;

    _panelState = state;
    _documentPath = documentPath;
    _leftSidebarWidth = leftSidebarWidth;

    if (sessionChanged) {
      _resetConversation(notify: false);
    } else if (startsNewRound) {
      _resumeScrollFollowing();
      _hasDeferredStreamingUpdate = false;
    }
    if (apiKeyChanged && _deepSeekController.text != state.apiKey) {
      _deepSeekController.text = state.apiKey;
    }

    _syncConversationWithPanelState();
    if (_scrollFollowState == _ScrollFollowState.userControlled &&
        state.loading) {
      _hasDeferredStreamingUpdate = true;
      return;
    }
    _hasDeferredStreamingUpdate = false;
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

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    bool resumedFollowing = false;
    if (notification is UserScrollNotification) {
      _userScrollDirection = notification.direction;
      if (notification.direction == ScrollDirection.idle) {
        return false;
      }

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
      if (!isClosed && requestId == _scrollRequestId) {
        _scrollToBottom();
      }
    });
  }

  void _flushDeferredStreamingUpdate() {
    if (!_hasDeferredStreamingUpdate || isClosed) {
      return;
    }
    _hasDeferredStreamingUpdate = false;
    update();
  }

  Future<void> handleSend(AiChatInput input) async {
    if (input.isEmpty) return;
    await sendMessage(input.text, image: input.image);
  }

  Future<void> sendMessage(String text, {AiImageAttachment? image}) async {
    final String trimmedText = text.trim();
    if (trimmedText.isEmpty && (image?.bytes.isEmpty ?? true)) {
      return;
    }
    _conversation.addUserMessage(
      text: trimmedText,
      imageBytes: image?.bytes,
    );
    _conversation.ensureLoadingPlaceholder();
    _resumeScrollFollowing();
    _hasDeferredStreamingUpdate = false;
    update();
    _scheduleScrollToBottom();
    await _onSendChat(AiChatInput(text: trimmedText, image: image));
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
    _conversation.syncResponse(
      loading: _panelState.loading,
      result: _panelState.result,
      reasoning: _panelState.reasoning,
      errorMessage: _panelState.errorMessage,
    );
  }

  void _syncAction(PdfAiPanelState state) {
    if (state.actionLabel == null || state.actionId == _lastActionId) {
      return;
    }

    _lastActionId = state.actionId;
    _conversation.addUserMessage(
      text: _buildActionUserText(state),
      imageBytes: state.actionSelectionImage,
    );
    _resumeScrollFollowing();
    _scheduleScrollToBottom();
  }

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

  void _resetConversation({required bool notify}) {
    _conversation.reset();
    _lastActionId = null;
    _inputController.clear();
    _resumeScrollFollowing();
    _userScrollDirection = ScrollDirection.idle;
    _scrollRequestId++;
    _hasDeferredStreamingUpdate = false;
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
