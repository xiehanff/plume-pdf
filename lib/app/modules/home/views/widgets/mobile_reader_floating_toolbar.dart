import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../routes/app_pages.dart';
import '../../../../theme/app_colors.dart';
import '../../controllers/home_controller.dart';
import '../../models/pdf_reader_state.dart';

/// 移动端阅读器右侧悬浮工具栏。
///
/// 只保留触屏场景仍然有价值的动作：大纲、AI、打开文件、WiFi 传书、
/// AI 框选、适宽、阅读背景与最近阅读。翻页、页码、缩放按钮和单双页
/// 均不占用移动端永久 UI 空间。
class MobileReaderFloatingToolbar extends StatelessWidget {
  const MobileReaderFloatingToolbar({
    super.key,
    required this.controller,
    required this.state,
  });

  static const double width = 52;
  static const double horizontalInset = 20;
  static const double _buttonExtent = 44;

  final HomeController controller;
  final PdfReaderState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(width / 2),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              spreadRadius: 1,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ToolbarButton(
              tooltip: '大纲',
              onPressed: () => Get.toNamed<void>(Routes.readerOutline),
              materialIcon: Icons.menu_rounded,
            ),
            _ToolbarButton(
              tooltip: 'AI 对话',
              onPressed: () => Get.toNamed<void>(Routes.readerAi),
              materialIcon: Icons.chat_bubble_outline_rounded,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Divider(height: 1, color: AppColors.borderSubtle),
            ),
            _ToolbarButton(
              tooltip: '打开文件',
              onPressed: controller.handleOpenFile,
              hugeIcon: HugeIcons.strokeRoundedFolderOpen,
            ),
            _ToolbarButton(
              tooltip: 'WiFi 传书',
              onPressed: () => Get.toNamed<void>(Routes.wifiTransfer),
              hugeIcon: HugeIcons.strokeRoundedWifi01,
            ),
            _ToolbarButton(
              tooltip: state.aiSelectionMode ? '退出 AI 框选' : 'AI 框选',
              onPressed: controller.toggleAiSelectionMode,
              selected: state.aiSelectionMode,
              hugeIcon: HugeIcons.strokeRoundedAiGenerative,
            ),
            _ToolbarButton(
              tooltip: '适宽',
              onPressed: controller.fitWidth,
              hugeIcon: HugeIcons.strokeRoundedArrowHorizontal,
            ),
            _BackgroundThemeButton(
              theme: state.backgroundTheme,
              onSelected: controller.setBackgroundTheme,
            ),
            _ToolbarButton(
              tooltip: '最近阅读',
              onPressed: controller.showRecentFiles,
              hugeIcon: HugeIcons.strokeRoundedTransactionHistory,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.tooltip,
    required this.onPressed,
    this.hugeIcon,
    this.materialIcon,
    this.selected = false,
  }) : assert(hugeIcon != null || materialIcon != null);

  final String tooltip;
  final VoidCallback? onPressed;
  final List<List<dynamic>>? hugeIcon;
  final IconData? materialIcon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MobileReaderFloatingToolbar._buttonExtent,
      height: MobileReaderFloatingToolbar._buttonExtent,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: selected
              ? AppColors.textPrimary
              : AppColors.textSecondary,
          disabledForegroundColor: AppColors.textTertiary.withValues(alpha: 0.45),
          backgroundColor: selected ? AppColors.seed : Colors.transparent,
          shape: const CircleBorder(),
        ),
        icon: materialIcon != null
            ? Icon(materialIcon, size: 21)
            : HugeIcon(icon: hugeIcon!, size: 19, strokeWidth: 1.5),
      ),
    );
  }
}

class _BackgroundThemeButton extends StatelessWidget {
  const _BackgroundThemeButton({required this.theme, required this.onSelected});

  final PdfBackgroundTheme theme;
  final ValueChanged<PdfBackgroundTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PdfBackgroundTheme>(
      tooltip: '阅读背景',
      initialValue: theme,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) {
        return PdfBackgroundTheme.values.map((PdfBackgroundTheme item) {
          return PopupMenuItem<PdfBackgroundTheme>(
            value: item,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 26,
                  child: item == theme
                      ? const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick01,
                          size: 17,
                          strokeWidth: 1.5,
                        )
                      : null,
                ),
                Text(item.label),
              ],
            ),
          );
        }).toList();
      },
      child: SizedBox(
        width: MobileReaderFloatingToolbar._buttonExtent,
        height: MobileReaderFloatingToolbar._buttonExtent,
        child: Center(
          child: HugeIcon(
            icon: _themeIcon(theme),
            color: AppColors.textSecondary,
            size: 19,
            strokeWidth: 1.5,
          ),
        ),
      ),
    );
  }

  List<List<dynamic>> _themeIcon(PdfBackgroundTheme value) {
    return switch (value) {
      PdfBackgroundTheme.normal => HugeIcons.strokeRoundedSun02,
      PdfBackgroundTheme.night => HugeIcons.strokeRoundedMoonFastWind,
      PdfBackgroundTheme.parchment => HugeIcons.strokeRoundedTissuePaper,
      PdfBackgroundTheme.green => HugeIcons.strokeRoundedLeaf01,
    };
  }
}
