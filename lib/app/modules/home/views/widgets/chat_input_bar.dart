import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../theme/app_colors.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
    required this.onNewSession,
    required this.onSettingsTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onNewSession;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 4,
              maxLines: 6,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: isLoading ? '思考中…' : '请问倒我…',
                hintStyle: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.surfaceBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderSoft),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderFocused),
                ),
              ),
              enabled: !isLoading,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                // 新建会话：任务进行中（loading）不可点击。
                onPressed: isLoading ? null : onNewSession,
                tooltip: '新建会话',
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedPlusSign,
                  size: 18,
                  strokeWidth: 1.5,
                ),
                color: AppColors.textSecondary,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  maximumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              IconButton(
                onPressed: isLoading ? null : onSend,
                tooltip: '发送',
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSent,
                  size: 18,
                  strokeWidth: 1.5,
                ),
                color: AppColors.textSecondary,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  maximumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              IconButton(
                onPressed: onSettingsTap,
                tooltip: '模型设置',
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAiSetting,
                  size: 15,
                  strokeWidth: 1.5,
                ),
                color: AppColors.textSecondary,
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 28),
                  maximumSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
