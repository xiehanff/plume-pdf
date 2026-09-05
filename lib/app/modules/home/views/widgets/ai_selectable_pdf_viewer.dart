import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../theme/app_colors.dart';
import '../../models/pdf_ai_selection.dart';
import '../../models/pdf_ai_tool_action.dart';
import 'ai_selection_mode_badge.dart';
import 'pdf_page_area_selection_overlay.dart';

class AiSelectablePdfViewer extends StatefulWidget {
  const AiSelectablePdfViewer({
    super.key,
    required this.filePath,
    required this.controller,
    required this.initialPage,
    required this.spreadMode,
    required this.lockHorizontalPan,
    required this.backgroundTheme,
    required this.aiSelectionEnabled,
    required this.onDocumentChanged,
    required this.onPageChanged,
    required this.onViewerReady,
    required this.onLoadError,
    required this.onSelectionChanged,
    required this.onActionSelected,
    this.onExitAiSelection,
    this.pageMargin = 24,
    this.showScrollThumb = true,
  });

  final String filePath;
  final PdfViewerController controller;
  final int initialPage;
  final bool spreadMode;
  final bool lockHorizontalPan;
  final PdfBackgroundTheme backgroundTheme;
  final bool aiSelectionEnabled;
  final void Function(String filePath, PdfDocument? document) onDocumentChanged;
  final void Function(String filePath, int? pageNumber) onPageChanged;
  final ValueChanged<String> onViewerReady;
  final void Function(String filePath, Object error, StackTrace? stackTrace)
  onLoadError;
  final ValueChanged<PdfAiSelection?> onSelectionChanged;
  final ValueChanged<AiToolAction> onActionSelected;

  /// AI 选择模式标签右侧圆形关闭按钮的回调；为 null 时不显示按钮
  /// （桌面端使用 Esc 退出，移动端传入退出逻辑）。
  final VoidCallback? onExitAiSelection;

  final double pageMargin;
  final bool showScrollThumb;

  @override
  State<AiSelectablePdfViewer> createState() => _AiSelectablePdfViewerState();
}

class _AiSelectablePdfViewerState extends State<AiSelectablePdfViewer> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surfaceBg),
      child: Stack(
        children: <Widget>[
          _buildPdfViewer(),
          if (widget.aiSelectionEnabled)
            Positioned(
              right: 28,
              top: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const IgnorePointer(child: AiSelectionModeBadge()),
                  if (widget.onExitAiSelection != null) ...<Widget>[
                    const SizedBox(width: 8),
                    _AiModeCloseButton(onTap: widget.onExitAiSelection!),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    final String sourceFilePath = widget.filePath;
    final int sourceInitialPage = widget.initialPage;
    final ColorFilter? colorFilter = widget.backgroundTheme.colorFilter;
    return PdfViewer.file(
      sourceFilePath,
      key: ValueKey<String>('$sourceFilePath:$sourceInitialPage'),
      controller: widget.controller,
      initialPageNumber: sourceInitialPage,
      params: PdfViewerParams(
        margin: widget.pageMargin,
        backgroundColor: AppColors.transparent,
        layoutPages:
            widget.spreadMode ? _spreadLayoutPages : _singleLayoutPages,
        useAlternativeFitScaleAsMinScale: false,
        panAxis: widget.lockHorizontalPan ? PanAxis.vertical : PanAxis.free,
        boundaryMargin: EdgeInsets.zero,
        scrollByMouseWheel: 0.9,
        pageDropShadow: null,
        onDocumentChanged: (PdfDocument? document) {
          widget.onDocumentChanged(sourceFilePath, document);
        },
        onPageChanged: (int? pageNumber) {
          widget.onPageChanged(sourceFilePath, pageNumber);
        },
        onViewerReady: (_, __) {
          widget.onViewerReady(sourceFilePath);
        },
        viewerOverlayBuilder: (context, size, handleLinkTap) => <Widget>[
          if (widget.showScrollThumb)
            PdfViewerScrollThumb(
              controller: widget.controller,
              orientation: ScrollbarOrientation.right,
              thumbSize: const Size(8, 48),
              margin: 4,
              thumbBuilder: (context, thumbSize, pageNumber, controller) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.borderVisible,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          if (widget.aiSelectionEnabled)
            PdfViewerAreaSelectionOverlay(
              controller: widget.controller,
              viewportSize: size,
              onSelectionChanged: widget.onSelectionChanged,
              onActionSelected: widget.onActionSelected,
              avoidTopRightControls: widget.onExitAiSelection != null,
            ),
        ],
        pageBackgroundPaintCallbacks: colorFilter == null
            ? null
            : <PdfViewerPagePaintCallback>[
                (canvas, pageRect, page) {
                  canvas.saveLayer(
                    pageRect,
                    Paint()..colorFilter = colorFilter,
                  );
                },
              ],
        pagePaintCallbacks: colorFilter == null
            ? null
            : <PdfViewerPagePaintCallback>[
                (canvas, pageRect, page) {
                  canvas.restore();
                },
              ],
        errorBannerBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
          PdfDocumentRef documentRef,
        ) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onLoadError(sourceFilePath, error, stackTrace);
          });
          return const SizedBox.shrink();
        },
      ),
    );
  }

  PdfPageLayout _singleLayoutPages(
    List<PdfPage> pages,
    PdfViewerParams params,
  ) {
    const double verticalGap = 0;
    final double outerMargin = params.margin;
    final double maxWidth = pages.fold<double>(
      0,
      (double previous, PdfPage page) => math.max(previous, page.width),
    );
    final List<Rect> pageLayouts = <Rect>[];
    double y = outerMargin;

    for (final PdfPage page in pages) {
      pageLayouts.add(
        Rect.fromLTWH(
          (maxWidth + outerMargin * 2 - page.width) / 2,
          y,
          page.width,
          page.height,
        ),
      );
      y += page.height + verticalGap;
    }

    final double documentHeight = pages.isEmpty
        ? outerMargin * 2
        : y - verticalGap + outerMargin;
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(outerMargin * 2 + maxWidth, documentHeight),
    );
  }

  PdfPageLayout _spreadLayoutPages(
    List<PdfPage> pages,
    PdfViewerParams params,
  ) {
    const double horizontalGap = 8;
    const double verticalGap = 0;
    final double outerMargin = params.margin;
    final double maxWidth = pages.fold<double>(
      0,
      (double previous, PdfPage page) => math.max(previous, page.width),
    );
    final List<Rect> pageLayouts = <Rect>[];
    double y = outerMargin;

    for (int i = 0; i < pages.length; i++) {
      final PdfPage page = pages[i];
      final bool isLeft = i.isEven;
      final int pairIndex = isLeft ? i + 1 : i - 1;
      final double pairHeight = pairIndex >= 0 && pairIndex < pages.length
          ? math.max(page.height, pages[pairIndex].height)
          : page.height;

      pageLayouts.add(
        Rect.fromLTWH(
          isLeft
              ? outerMargin + maxWidth - page.width
              : outerMargin + maxWidth + horizontalGap,
          y + (pairHeight - page.height) / 2,
          page.width,
          page.height,
        ),
      );

      if (!isLeft || i + 1 == pages.length) {
        y += pairHeight + verticalGap;
      }
    }

    final double documentHeight = pages.isEmpty
        ? outerMargin * 2
        : y - verticalGap + outerMargin;
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(
        outerMargin + maxWidth + horizontalGap + maxWidth + outerMargin,
        documentHeight,
      ),
    );
  }
}

/// AI 选择模式标签右侧的圆形退出按钮，
/// 与悬浮工具栏同款毛玻璃背景。
class _AiModeCloseButton extends StatelessWidget {
  const _AiModeCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: AppColors.scaffoldBg.withValues(alpha: 0.65),
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.borderSubtle),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
