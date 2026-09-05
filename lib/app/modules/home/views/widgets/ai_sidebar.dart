import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:plume_ai_chat/plume_ai_chat.dart'
    show AiChatMessageList, ChatMessage;

import '../../../../theme/app_colors.dart';
import '../../controllers/ai_sidebar_controller.dart';
import '../../models/ai_chat_input.dart';
import 'ai_sidebar_settings.dart';
import 'chat_bubble.dart';
import 'chat_input_bar.dart';

class AiSidebar extends StatelessWidget {
  const AiSidebar({
    super.key,
    this.fullWidth = false,
    this.controllerTag = AiSidebarController.tag,
  });

  final bool fullWidth;
  final String controllerTag;

  @override
  Widget build(BuildContext context) {
    // 正常阅读界面由 HomeController 持有 Controller；调试预览可通过
    // controllerTag 使用独立实例，避免共享或误删生产会话状态。
    return GetBuilder<AiSidebarController>(
      tag: controllerTag,
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

  bool get _needsApiKeySetup => controller.state.apiKey.trim().isEmpty;

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
            Expanded(child: _buildMessageList(context)),
            ChatInputBar(
              controller: controller.inputController,
              focusNode: controller.inputFocusNode,
              isLoading: controller.isLoading,
              onSend: (AiChatInput input) async {
                // 移动端全屏模式：未配置 API Key 时发送直接打开配置弹窗，
                // 避免首次使用者面对无引导的错误提示。
                if (fullWidth && _needsApiKeySetup) {
                  _showSettingsSheet(context);
                  return;
                }
                await controller.handleSend(input);
              },
              onStop: controller.onStopChat,
              onNewSession: controller.onNewSession,
              onSettingsTap: fullWidth
                  ? () => _showSettingsSheet(context)
                  : controller.showSettings,
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

  /// 移动端设置以底部弹窗呈现，替代嵌套在 AI 页面内的子视图切换。
  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.scaffoldBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSoft,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text(
                    '设置',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AiSidebarSettingsList(
                  deepSeekController: controller.deepSeekController,
                  onDeepSeekChanged: controller.onApiKeyChanged,
                  onSaveDeepSeek: () async {
                    final String apiKey = controller.deepSeekController.text
                        .trim();
                    if (apiKey.isEmpty) {
                      return;
                    }

                    // 保存前统一去掉用户误输入的首尾空白；状态同步是同步的，
                    // 随后的 save 会持久化修正后的值。
                    if (apiKey != controller.state.apiKey) {
                      controller.onApiKeyChanged(apiKey);
                    }
                    await controller.onSaveApiKey();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  shrinkWrap: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final List<ChatMessage> messages = controller.messages;
    if (messages.isEmpty) {
      if (fullWidth && _needsApiKeySetup) {
        return _FirstUseGuide(
          onConfigure: () => _showSettingsSheet(context),
        );
      }
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

    final bool showFollowUpSuggestions = controller.showFollowUpSuggestions;
    final List<String> followUpSuggestions = controller.followUpSuggestions;
    return AiChatMessageList(
      messages: messages,
      controller: controller.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      onScrollNotification: controller.handleScrollNotification,
      onPointerSignal: controller.handlePointerSignal,
      messageBuilder: (
        BuildContext context,
        ChatMessage message,
        int index,
      ) {
        return ChatBubble(message: message);
      },
      trailingBuilder: showFollowUpSuggestions
          ? (BuildContext context) => _FollowUpSuggestions(
                suggestions: followUpSuggestions,
                onTap: (String text) => controller.sendMessage(text),
              )
          : null,
    );
  }
}

/// 首次使用引导：未配置 API Key 时替代空会话提示，直接指路配置入口。
class _FirstUseGuide extends StatelessWidget {
  const _FirstUseGuide({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.fillSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedKey01,
                size: 30,
                strokeWidth: 1.5,
                color: AppColors.accentBright,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '首次使用需要配置 API Key',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'AI 对话与框选解读使用 DeepSeek 模型，\n填写你自己的 DeepSeek API Key 后即可使用。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onConfigure,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentSurface,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSettings01,
                size: 16,
                strokeWidth: 1.5,
              ),
              label: const Text('去配置'),
            ),
          ],
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
