import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../models/ai_chat_input.dart';
import '../models/pdf_ai_panel_state.dart';
import 'ai_sidebar_controller.dart';

/// AI 侧栏的流式性能控制层。
///
/// [AiSidebarController] 继续负责消息状态与 FollowTailScrollController 的
/// 滚动语义；本类只解决一个性能问题：用户已经滚离底部阅读历史时，
/// 模型每个 preview 仍会触发 GetBuilder rebuild、Markdown build/layout，
/// 与手势滚动争抢 UI 线程。
///
/// 因此在“用户控制滚动 + 模型仍在流式输出”期间：
/// - 仍调用父类同步最新 panel/message 数据；
/// - 仅拦截这次由 updateExternalState 触发的 update()；
/// - 回到底部阈值、开始新一轮消息或流结束时一次性 flush 最新 UI。
///
/// 非流式更新、设置页操作、发送消息等普通 update 不受影响。
class StreamingAiSidebarController extends AiSidebarController {
  StreamingAiSidebarController({
    required super.state,
    required super.onApiKeyChanged,
    required super.onSaveApiKey,
    required super.onSendChat,
    required super.onNewSession,
    super.documentPath,
    super.leftSidebarWidth,
  });

  static const double _kBottomFollowThreshold = 80;

  bool _userControlled = false;
  bool _suppressExternalUpdate = false;
  bool _hasDeferredStreamingUpdate = false;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;

  @override
  void updateExternalState({
    required PdfAiPanelState state,
    required String? documentPath,
    required double leftSidebarWidth,
    required ValueChanged<String> onApiKeyChanged,
    required Future<void> Function() onSaveApiKey,
    required SendChatCallback onSendChat,
    required VoidCallback onNewSession,
  }) {
    final bool startsNewRound =
        state.sessionId != this.state.sessionId ||
        (state.actionId != null && state.actionId != this.state.actionId);
    if (startsNewRound) {
      _userControlled = false;
      _hasDeferredStreamingUpdate = false;
    }

    _suppressExternalUpdate = _userControlled && state.loading;
    try {
      super.updateExternalState(
        state: state,
        documentPath: documentPath,
        leftSidebarWidth: leftSidebarWidth,
        onApiKeyChanged: onApiKeyChanged,
        onSaveApiKey: onSaveApiKey,
        onSendChat: onSendChat,
        onNewSession: onNewSession,
      );
    } finally {
      _suppressExternalUpdate = false;
    }
  }

  @override
  void update([List<Object>? ids, bool condition = true]) {
    if (_suppressExternalUpdate && condition) {
      _hasDeferredStreamingUpdate = true;
      return;
    }
    _hasDeferredStreamingUpdate = false;
    super.update(ids, condition);
  }

  @override
  bool handleScrollNotification(ScrollNotification notification) {
    final bool handled = super.handleScrollNotification(notification);
    if (notification.depth != 0) {
      return handled;
    }

    bool shouldFlush = false;
    if (notification is UserScrollNotification) {
      _userScrollDirection = notification.direction;
      if (notification.direction != ScrollDirection.idle) {
        _userControlled = true;
      }
      if (notification.direction == ScrollDirection.reverse &&
          notification.metrics.extentAfter <= _kBottomFollowThreshold) {
        _userControlled = false;
        shouldFlush = true;
      }
    } else if (notification is ScrollUpdateNotification &&
        _userScrollDirection == ScrollDirection.reverse &&
        notification.metrics.extentAfter <= _kBottomFollowThreshold) {
      _userControlled = false;
      shouldFlush = true;
    }

    if (shouldFlush) {
      _flushDeferredStreamingUpdate();
    }
    return handled;
  }

  @override
  void handlePointerSignal(PointerSignalEvent event) {
    bool takesUserControl = false;
    if (event is PointerScrollEvent && scrollController.hasClients) {
      final double delta = event.scrollDelta.dy;
      final ScrollPosition position = scrollController.position;
      takesUserControl =
          delta != 0 &&
          !((delta < 0 && position.pixels <= position.minScrollExtent) ||
              (delta > 0 && position.pixels >= position.maxScrollExtent));
    }

    super.handlePointerSignal(event);
    if (takesUserControl) {
      _userControlled = true;
    }
  }

  @override
  Future<void> sendMessage(String text, {AiImageAttachment? image}) {
    // 用户主动发送新消息意味着重新关注最新回答；父类会恢复贴底。
    _userControlled = false;
    _hasDeferredStreamingUpdate = false;
    return super.sendMessage(text, image: image);
  }

  void _flushDeferredStreamingUpdate() {
    if (!_hasDeferredStreamingUpdate || isClosed) {
      return;
    }
    _hasDeferredStreamingUpdate = false;
    // 直接调用父类 update，避免再次经过本类的抑制判断。
    super.update();
  }
}
