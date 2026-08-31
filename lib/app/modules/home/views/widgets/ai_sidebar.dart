import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_colors.dart';
import '../../controllers/ai_sidebar_controller.dart';
import 'ai_sidebar_settings.dart';
import 'chat_bubble.dart';
import 'chat_input_bar.dart';
import 'chat_message.dart';

class AiSidebar extends StatelessWidget {
  const AiSidebar({super.key, this.fullWidth = false});

  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    // Controller 由 HomeController（桌面）或 MobileAiView（移动端）创建并注册。
    // 侧栏/路由开关期间实例常驻，会话历史保留。
    return GetBuilder<AiSidebarController>(
      tag: AiSidebarController.tag,
      builder: (AiSidebarController controller) {
        return _AiSidebarView(controller: controller, fullWidth: fullWidth);
      },
    );
  }
}

class _AiSidebarView extends StatelessWidget {
  static const double _kHandleWidth = 6;

  const _AiSidebarView({
    required this.controller,
    required this.fullWidth,
  });

  final AiSidebarController controller;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final Widget content = ColoredBox(
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
    );

    if (fullWidth) {
      return SizedBox.expand(child: content);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (DragUpdateDetails details) {
            controller.handleResize(
              details,
              MediaQuery.of(context).size.width,
            );
          },
          child: const MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: SizedBox(width: _kHandleWidth, height: double.infinity),
          ),
        ),
        SizedBox(width: controller.sidebarWidth, child: content),
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
        onPointerSignal: controller.handlePointerSignal,
        child: ListView.builder(
          controller: controller.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          itemCount:
              messages.length +
              (followUpState == AiSidebarFollowUpState.visible ? 1 : 0),
          itemBuilder: (BuildContext context, int index) {
            if (followUpState == AiSidebarFollowUpState.visible &&
                index == messages.length) {
              return _FollowUpSuggestions(
                suggestions: followUpSuggestions,
                onTap: (String text) => controller.sendMessage(text),
              );
            }
            return ChatBubble(
              key: ValueKey<String>(messages[index].id),
              message: messages[index],
            );
          },
        ),
      ),
    );
  }
}

/// 模型回复完成后展示的追问建议（Wrap 组件）。
class _FollowUpSuggestions extends StatelessWidget {
  const _FollowUpSuggestions({
    required this.suggestions,
    required this.onTap,
  });

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
