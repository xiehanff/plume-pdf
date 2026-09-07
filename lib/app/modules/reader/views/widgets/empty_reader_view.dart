import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'reader_shortcut_platform.dart';
import 'reader_state_card.dart';
import '../../../../theme/app_colors.dart';

class EmptyReaderView extends StatelessWidget {
  const EmptyReaderView({
    super.key,
    required this.onOpenFile,
    this.onOpenWifiTransfer,
  });

  final VoidCallback onOpenFile;
  final VoidCallback? onOpenWifiTransfer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool mobileActions = onOpenWifiTransfer != null;
    return ReaderStateCard(
      title: '打开本地 PDF',
      body: Text(
        '开始探索',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.6,
        ),
      ),
      action: !mobileActions
          ? _buildLocalButton()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildLocalButton(),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onOpenWifiTransfer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderFocused),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedWifi01,
                    size: 18,
                    strokeWidth: 1.5,
                  ),
                  label: const Text('通过 WiFi 传书'),
                ),
              ],
            ),
      footer: mobileActions
          ? null
          : Text(
              '快捷键：${primaryShortcutModifierLabel()} + O',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
    );
  }

  Widget _buildLocalButton() {
    return FilledButton.icon(
      onPressed: onOpenFile,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accentSurface,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      icon: const HugeIcon(
        icon: HugeIcons.strokeRoundedFolderOpen,
        size: 18,
        strokeWidth: 1.5,
      ),
      label: const Text('选择 PDF 文件'),
    );
  }
}