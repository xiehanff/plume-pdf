import 'package:flutter/material.dart';

import 'reader_shortcut_platform.dart';
import 'reader_state_card.dart';
import '../../../../theme/app_colors.dart';

class ErrorReaderView extends StatelessWidget {
  const ErrorReaderView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ReaderStateCard(
      title: '文档打开失败',
      body: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
      action: OutlinedButton(
        onPressed: onRetry,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderVisible),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        child: const Text('重新选择文件'),
      ),
      footer: Text(
        '快捷键：${primaryShortcutModifierLabel()} + O',
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}
