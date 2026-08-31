import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../routes/app_pages.dart';
import '../../../../theme/app_colors.dart';
import '../../controllers/home_controller.dart';
import '../../models/pdf_reader_state.dart';

class MobileReaderBottomBar extends StatelessWidget {
  const MobileReaderBottomBar({
    super.key,
    required this.controller,
    required this.state,
  });

  static const double height = 56;

  final HomeController controller;
  final PdfReaderState state;

  @override
  Widget build(BuildContext context) {
    final bool hasDocument = state.hasDocument && state.pageCount > 0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 6),
            _MobileToolbarButton(
              tooltip: '目录',
              onPressed: hasDocument
                  ? () => Get.toNamed<void>(Routes.readerOutline)
                  : null,
              icon: HugeIcons.strokeRoundedSidebarLeft,
            ),
            _MobileToolbarButton(
              tooltip: 'AI',
              onPressed: () => Get.toNamed<void>(Routes.readerAi),
              selected: state.aiSelectionMode,
              icon: HugeIcons.strokeRoundedSidebarRight,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.borderSubtle,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: <Widget>[
                    _MobileToolbarButton(
                      tooltip: '打开文件',
                      onPressed: controller.handleOpenFile,
                      icon: HugeIcons.strokeRoundedFolderOpen,
                    ),
                    if (hasDocument) ...<Widget>[
                      _MobileToolbarButton(
                        tooltip: '上一页',
                        onPressed: controller.goToPreviousPage,
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                      ),
                      _PageButton(
                        currentPage: state.currentPage,
                        pageCount: state.pageCount,
                        onTap: () => _showPageJumpDialog(context),
                      ),
                      _MobileToolbarButton(
                        tooltip: '下一页',
                        onPressed: controller.goToNextPage,
                        icon: HugeIcons.strokeRoundedArrowRight01,
                      ),
                      _MobileToolbarButton(
                        tooltip: '缩小',
                        onPressed: controller.zoomOut,
                        icon: HugeIcons.strokeRoundedMinusSign,
                      ),
                      _ZoomButton(
                        zoom: state.zoom,
                        onPressed: controller.actualSize,
                      ),
                      _MobileToolbarButton(
                        tooltip: '放大',
                        onPressed: controller.zoomIn,
                        icon: HugeIcons.strokeRoundedAdd01,
                      ),
                      _MobileToolbarButton(
                        tooltip: '适宽',
                        onPressed: controller.fitWidth,
                        icon: HugeIcons.strokeRoundedArrowHorizontal,
                      ),
                      _MobileToolbarButton(
                        tooltip: state.spreadMode ? '双页模式' : '单页模式',
                        selected: state.spreadMode,
                        onPressed: controller.toggleSpreadMode,
                        icon: state.spreadMode
                            ? HugeIcons.strokeRoundedBookOpenCheck
                            : HugeIcons.strokeRoundedBookOpen01,
                      ),
                      _MobileToolbarButton(
                        tooltip: state.aiSelectionMode
                            ? '退出 AI 选择模式'
                            : 'AI 选择模式',
                        selected: state.aiSelectionMode,
                        onPressed: controller.toggleAiSelectionMode,
                        icon: HugeIcons.strokeRoundedAiGenerative,
                      ),
                    ],
                    _BackgroundThemeButton(
                      theme: state.backgroundTheme,
                      onSelected: controller.setBackgroundTheme,
                    ),
                    _MobileToolbarButton(
                      tooltip: '最近阅读',
                      onPressed: controller.showRecentFiles,
                      icon: HugeIcons.strokeRoundedTransactionHistory,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _showPageJumpDialog(BuildContext context) async {
    final TextEditingController textController = TextEditingController(
      text: '${state.currentPage}',
    );
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        void submit() {
          controller.jumpToPage(textController.text);
          Navigator.of(dialogContext).pop();
        }

        return AlertDialog(
          title: const Text('跳转页面'),
          content: TextField(
            controller: textController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(
              hintText: '1 - ${state.pageCount}',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(onPressed: submit, child: const Text('跳转')),
          ],
        );
      },
    );
    textController.dispose();
  }
}

class _MobileToolbarButton extends StatelessWidget {
  const _MobileToolbarButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final List<List<dynamic>> icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: HugeIcon(icon: icon, size: 19, strokeWidth: 1.5),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.currentPage,
    required this.pageCount,
    required this.onTap,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(74, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.fillFaint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        '$currentPage / $pageCount',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.zoom, required this.onPressed});

  final double zoom;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(58, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.fillFaint,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          '${(zoom * 100).round()}%',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _BackgroundThemeButton extends StatelessWidget {
  const _BackgroundThemeButton({
    required this.theme,
    required this.onSelected,
  });

  final PdfBackgroundTheme theme;
  final ValueChanged<PdfBackgroundTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PdfBackgroundTheme>(
      tooltip: '阅读背景',
      initialValue: theme,
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
        width: 44,
        height: 44,
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
