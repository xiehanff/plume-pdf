import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../theme/app_colors.dart';
import '../../models/pdf_ai_selection.dart';
import '../../services/deepseek_service.dart';
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
    required this.onPageChanged,
    required this.onDocumentChanged,
    required this.onViewerReady,
    required this.onLoadError,
    required this.onSelectionChanged,
    required this.onActionSelected,
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
  final ValueChanged<int?> onPageChanged;
  final ValueChanged<PdfDocument?> onDocumentChanged;
  final void Function(PdfDocument, PdfViewerController) onViewerReady;
  final void Function(Object, StackTrace?) onLoadError;
  final ValueChanged<PdfAiSelection?> onSelectionChanged;
  final ValueChanged<AiToolAction> onActionSelected;
  final double pageMargin;
  final bool showScrollThumb;

  @override
  State<AiSelectablePdfViewer> createState() => _AiSelectablePdfViewerState();
}

class _AiSelectablePdfViewerState extends State<AiSelectablePdfViewer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surfaceBg),
      child: Stack(
        children: <Widget>[
          _buildPdfViewer(),
          if (widget.aiSelectionEnabled)
            const Positioned(
              right: 20,
              top: 20,
              child: IgnorePointer(child: AiSelectionModeBadge()),
            ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    final ColorFilter? colorFilter = widget.backgroundTheme.colorFilter;
    return PdfViewer.file(
      widget.filePath,
      key: ValueKey<String>('${widget.filePath}:${widget.initialPage}'),
      controller: widget.controller,
      initialPageNumber: widget.initialPage,
      params: PdfViewerParams(
        margin: widget.pageMargin,
        backgroundColor: AppColors.transparent,
        layoutPages:
            widget.spreadMode ? _spreadLayoutPages : _singleLayoutPages,
        useAlternativeFitScaleAsMinScale: false,
        panAxis: widget.lockHorizontalPan ? PanAxis.vertical : PanAxis.free,
        boundaryMargin: EdgeInsets.zero,
        scrollByMouseWheel: 0.9,
        pageDropShadow: const BoxShadow(
          color: AppColors.pageShadow,
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
        onPageChanged: widget.onPageChanged,
        onDocumentChanged: widget.onDocumentChanged,
        onViewerReady: widget.onViewerReady,
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
        ],
        pageOverlaysBuilder: (
          BuildContext context,
          Rect pageRect,
          PdfPage page,
        ) {
          return <Widget>[
            PdfPageAreaSelectionOverlay(
              page: page,
              pageRect: pageRect,
              aiSelectionEnabled: widget.aiSelectionEnabled,
              onSelectionChanged: widget.onSelectionChanged,
              onActionSelected: widget.onActionSelected,
            ),
          ];
        },
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
            widget.onLoadError(error, stackTrace);
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
    const double innerGap = 8;
    final double outerMargin = params.margin;
    final double maxWidth = pages.fold<double>(
      0,
      (double previous, PdfPage page) => math.max(previous, page.width),
    );
    final List<Rect> pageLayouts = <Rect>[];
    double y = outerMargin;

    for (int i = 0; i < pages.length; i++) {
      final PdfPage page = pages[i];
      pageLayouts.add(
        Rect.fromLTWH(
          (maxWidth + outerMargin * 2 - page.width) / 2,
          y,
          page.width,
          page.height,
        ),
      );
      y += page.height + innerGap;
    }

    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(
        outerMargin * 2 + maxWidth,
        y - innerGap + outerMargin,
      ),
    );
  }

  PdfPageLayout _spreadLayoutPages(
    List<PdfPage> pages,
    PdfViewerParams params,
  ) {
    const double innerGap = 8;
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
              : outerMargin + maxWidth + innerGap,
          y + (pairHeight - page.height) / 2,
          page.width,
          page.height,
        ),
      );

      if (!isLeft || i + 1 == pages.length) {
        y += pairHeight + innerGap;
      }
    }

    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(
        outerMargin + maxWidth + innerGap + maxWidth + outerMargin,
        y,
      ),
    );
  }
}
