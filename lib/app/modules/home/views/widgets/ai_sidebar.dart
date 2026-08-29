import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../controllers/ai_sidebar_controller.dart';
import 'ai_sidebar_settings.dart';
import 'chat_bubble.dart';
import 'chat_input_bar.dart';
import 'chat_message.dart';

class AiSidebar extends StatelessWidget {
  const AiSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    // Controller 由 HomeController 创建并注册（不传 init），
    // 侧栏开关期间实例常驻，会话历史保留。
    return GetBuilder<AiSidebarController>(
      tag: AiSidebarController.tag,
      builder: (AiSidebarController controller) {
        return _AiSidebarView(controller: controller);
      },
    );
  }
}

class _AiSidebarView extends StatelessWidget {
  static const double _kHandleWidth = 6;

  const _AiSidebarView({required this.controller});

  final AiSidebarController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            controller.handleResize(details, MediaQuery.of(context).size.width);
          },
          child: const MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: SizedBox(width: _kHandleWidth, height: double.infinity),
          ),
        ),
        Container(
          width: controller.sidebarWidth,
          color: AppColors.scaffoldBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (controller.mode == AiSidebarMode.settings)
                AiSidebarSettingsHeader(onBack: controller.showConversation),
              if (controller.mode == AiSidebarMode.settings)
                Expanded(
                  child: AiSidebarSettingsList(
                    deepSeekController: controller.deepSeekController,
                    onDeepSeekChanged: controller.onApiKeyChanged,
                    onSaveDeepSeek: controller.onSaveApiKey,
                  ),
                )
              else ...<Widget>[
                Expanded(child: _buildMessageList()),
                ChatInputBar(
                  controller: controller.inputController,
                  focusNode: controller.inputFocusNode,
                  isLoading: controller.state.loading,
                  onSend: controller.handleSend,
                  onNewSession: controller.onNewSession,
                  onSettingsTap: controller.showSettings,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    final List<ChatMessage> messages = controller.messages;
    if (messages.isEmpty) {
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

    final AiSidebarFollowUpState followUpState = controller.followUpState;
    final List<String> followUpSuggestions = controller.followUpSuggestions;
    return NotificationListener<ScrollNotification>(
      onNotification: controller.handleScrollNotification,
      child: Listener(
        // 在 Scrollable 发出滚动通知前，先使已排队的自动跟随失效。
        onPointerSignal: controller.handlePointerSignal,
        child: ListView.builder(
          controller: controller.scrollController,
          // reverse 布局把最新消息锚定在底部：流式输出时内容向上生长，
          // 贴底跟随无需逐帧 jumpTo 修正，消除滚动位置抖动。
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          itemCount:
              messages.length +
              (followUpState == AiSidebarFollowUpState.visible ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            final bool hasFollowUp =
                followUpState == AiSidebarFollowUpState.visible;
            // reverse 布局：index 0 位于视觉最底部（最新内容）。
            if (hasFollowUp && index == 0) {
              return _FollowUpSuggestions(
                suggestions: followUpSuggestions,
                onTap: (String text) => controller.sendMessage(text),
              );
            }
            final int messageIndex = hasFollowUp
                ? messages.length - index
                : messages.length - 1 - index;
            final ChatMessage message = messages[messageIndex];
            final Widget bubble = ChatBubble(
              key: ValueKey<String>(message.id),
              message: message,
            );
            // 最新气泡在流式输出中不断增高，会持续上推历史内容；
            // 包一层高度监听，由控制器在用户阅读历史时补偿滚动位置。
            if (messageIndex == messages.length - 1) {
              return _StreamTailSizeObserver(
                key: ValueKey<String>('size_${message.id}'),
                onHeightChanged: controller.compensateStreamGrowth,
                child: bubble,
              );
            }
            return bubble;
          },
        ),
      ),
    );
  }
}

/// 模型回复完成后展示的追问建议（Wrap 组件）。
class _FollowUpSuggestions extends StatelessWidget {
  const _FollowUpSuggestions({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final String text in suggestions)
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

/// 监听最新消息气泡的高度变化，向控制器报告增量。
///
/// reverse 布局中该气泡位于视觉最底部，流式输出使其增高时会把
/// 历史内容整体上推；控制器据此在用户阅读历史时补偿滚动位置。
/// 高度在 layout 阶段得出，而滚动补偿不能在 layout 中执行，
/// 因此把增量攒到帧末统一回调。
class _StreamTailSizeObserver extends SingleChildRenderObjectWidget {
  const _StreamTailSizeObserver({
    super.key,
    required this.onHeightChanged,
    super.child,
  });

  final void Function(double delta) onHeightChanged;

  @override
  RenderStreamTailSizeObserver createRenderObject(BuildContext context) =>
      RenderStreamTailSizeObserver(onHeightChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderStreamTailSizeObserver renderObject,
  ) {
    renderObject.onHeightChanged = onHeightChanged;
  }
}

class RenderStreamTailSizeObserver extends RenderProxyBox {
  RenderStreamTailSizeObserver(this.onHeightChanged);

  void Function(double delta) onHeightChanged;
  double? _lastHeight;
  double _pendingDelta = 0;
  bool _deltaScheduled = false;

  @override
  void performLayout() {
    super.performLayout();
    final double? lastHeight = _lastHeight;
    _lastHeight = size.height;
    if (lastHeight == null || size.height == lastHeight) {
      return;
    }
    _pendingDelta += size.height - lastHeight;
    if (_deltaScheduled) {
      return;
    }
    _deltaScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _deltaScheduled = false;
      final double delta = _pendingDelta;
      _pendingDelta = 0;
      if (delta != 0) {
        onHeightChanged(delta);
      }
    });
  }
}
