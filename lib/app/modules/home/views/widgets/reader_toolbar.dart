import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../theme/app_colors.dart';
import 'page_navigator.dart';

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({
    super.key,
    required this.fileName,
    required this.hasDocument,
    required this.pageController,
    required this.currentPage,
    required this.pageCount,
    required this.zoomLabel,
    required this.sidebarVisible,
    required this.spreadMode,
    required this.aiSelectionMode,
    required this.aiSidebarVisible,
    required this.onOpenFile,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSubmitted,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onFitWidth,
    required this.onActualSize,
    required this.onToggleSidebar,
    required this.onToggleSpreadMode,
    required this.onToggleAiSelectionMode,
    required this.onToggleAiSidebar,
    required this.onShowRecentFiles,
    required this.onSetBackgroundTheme,
    required this.backgroundTheme,
  });

  final String? fileName;
  final bool hasDocument;
  final TextEditingController pageController;
  final int currentPage;
  final int pageCount;
  final String zoomLabel;
  final bool sidebarVisible;
  final bool spreadMode;
  final bool aiSelectionMode;
  final bool aiSidebarVisible;
  final VoidCallback onOpenFile;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<String> onPageSubmitted;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onFitWidth;
  final VoidCallback onActualSize;
  final VoidCallback onToggleSidebar;
  final VoidCallback onToggleSpreadMode;
  final VoidCallback onToggleAiSelectionMode;
  final VoidCallback onToggleAiSidebar;
  final VoidCallback onShowRecentFiles;
  final ValueChanged<PdfBackgroundTheme> onSetBackgroundTheme;
  final PdfBackgroundTheme backgroundTheme;

  @override
  Widget build(BuildContext context) {
    final bool isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final bool showCenteredAppTitle = isWindows && !hasDocument;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.scaffoldBg,
      child: Stack(
        children: <Widget>[
          // 中间：页码导航 + 缩放（绝对居中，不影响左右布局）
          if (hasDocument)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PageNavigator(
                    controller: pageController,
                    currentPage: currentPage,
                    pageCount: pageCount,
                    onPreviousPage: onPreviousPage,
                    onNextPage: onNextPage,
                    onSubmitted: onPageSubmitted,
                  ),
                  const SizedBox(width: 12),
                  _ZoomLabelButton(label: zoomLabel, onPressed: onActualSize),
                ],
              ),
            )
          else if (showCenteredAppTitle)
            const Center(
              child: Text(
                'Plume PDF',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // 左侧：侧边栏 + 打开文件 + 文件名
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ToolbarIconButton(
                  tooltip: '侧边栏',
                  onPressed: onToggleSidebar,
                  selected: sidebarVisible,
                  child: _HugeToolbarIcon(
                    icon: sidebarVisible
                        ? HugeIcons.strokeRoundedSidebarLeft
                        : HugeIcons.strokeRoundedLayoutAlignLeft,
                  ),
                ),
                const SizedBox(width: 4),
                _ToolbarIconButton(
                  tooltip: '打开文件',
                  onPressed: onOpenFile,
                  child: const _HugeToolbarIcon(
                    icon: HugeIcons.strokeRoundedFolderOpen,
                  ),
                ),
              ],
            ),
          ),
          // 右侧：历史记录 + 阅读工具
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _ToolbarIconButton(
                    tooltip: '最近阅读',
                    onPressed: onShowRecentFiles,
                    child: const _HugeToolbarIcon(
                      icon: HugeIcons.strokeRoundedTransactionHistory,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _BackgroundThemeMenu(
                    theme: backgroundTheme,
                    onSelected: onSetBackgroundTheme,
                  ),
                  if (hasDocument) const SizedBox(width: 4),
                  if (hasDocument) ...<Widget>[
                    _ToolbarIconButton(
                      tooltip: spreadMode ? '双页模式' : '单页模式',
                      selected: spreadMode,
                      onPressed: onToggleSpreadMode,
                      child: _HugeToolbarIcon(
                        icon: spreadMode
                            ? HugeIcons.strokeRoundedBookOpenCheck
                            : HugeIcons.strokeRoundedBookOpen01,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarIconButton(
                      tooltip: aiSelectionMode ? '退出 AI 选择模式' : 'AI 选择模式',
                      selected: aiSelectionMode,
                      onPressed: onToggleAiSelectionMode,
                      child: const _HugeToolbarIcon(
                        icon: HugeIcons.strokeRoundedAiGenerative,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarIconButton(
                      tooltip: '适宽',
                      onPressed: onFitWidth,
                      child: const _HugeToolbarIcon(
                        icon: HugeIcons.strokeRoundedArrowHorizontal,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarIconButton(
                      tooltip: '缩小',
                      onPressed: onZoomOut,
                      child: const _HugeToolbarIcon(
                        icon: HugeIcons.strokeRoundedMinusSign,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarIconButton(
                      tooltip: '放大',
                      onPressed: onZoomIn,
                      child: const _HugeToolbarIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarIconButton(
                      tooltip: aiSidebarVisible ? '隐藏 AI 侧边栏' : '显示 AI 侧边栏',
                      selected: aiSidebarVisible,
                      onPressed: onToggleAiSidebar,
                      child: const _HugeToolbarIcon(
                        icon: HugeIcons.strokeRoundedSidebarRight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomLabelButton extends StatelessWidget {
  const _ZoomLabelButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.fillSubtle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.onPressed,
    this.child,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget? child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: const Size(30, 30),
        maximumSize: const Size(30, 30),
        padding: EdgeInsets.zero,
        foregroundColor: selected
            ? AppColors.textPrimary
            : AppColors.textSecondary,
        backgroundColor: selected ? AppColors.seed : AppColors.fillFaint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: child!,
    );
  }
}

class _HugeToolbarIcon extends StatelessWidget {
  const _HugeToolbarIcon({required this.icon});

  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(icon: icon, size: 16, strokeWidth: 1.5);
  }
}

class _BackgroundThemeMenu extends StatelessWidget {
  const _BackgroundThemeMenu({required this.theme, required this.onSelected});

  final PdfBackgroundTheme theme;
  final ValueChanged<PdfBackgroundTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PdfBackgroundTheme>(
      tooltip: '阅读背景',
      initialValue: theme,
      offset: const Offset(0, 36),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) {
        return PdfBackgroundTheme.values.map((PdfBackgroundTheme t) {
          final bool isCurrent = t == theme;
          return PopupMenuItem<PdfBackgroundTheme>(
            value: t,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 24,
                  child: isCurrent
                      ? const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick01,
                          size: 16,
                          strokeWidth: 1.5,
                        )
                      : const SizedBox.shrink(),
                ),
                Text(t.label, style: const TextStyle(fontSize: 13)),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.fillFaint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(child: _BackgroundThemeIcon(theme: theme)),
      ),
    );
  }
}

class _BackgroundThemeIcon extends StatelessWidget {
  const _BackgroundThemeIcon({required this.theme});

  final PdfBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    final List<List<dynamic>> icon;
    switch (theme) {
      case PdfBackgroundTheme.normal:
        icon = HugeIcons.strokeRoundedSun02;
        break;
      case PdfBackgroundTheme.night:
        icon = HugeIcons.strokeRoundedMoonFastWind;
        break;
      case PdfBackgroundTheme.parchment:
        icon = HugeIcons.strokeRoundedTissuePaper;
        break;
      case PdfBackgroundTheme.green:
        icon = HugeIcons.strokeRoundedLeaf01;
        break;
    }
    return HugeIcon(icon: icon, size: 16, strokeWidth: 1.5);
  }
}
