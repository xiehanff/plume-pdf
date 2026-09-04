import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../theme/app_colors.dart';
import '../../models/pdf_ai_selection.dart';
import '../../services/deepseek_service.dart';
import 'selection_toolbar_placement.dart';

enum DragMode { none, create, move }

/// PDF Viewer 级别的 AI 区域框选层。
///
/// 与旧的 pageOverlaysBuilder 方案不同，这里整个 PdfViewer 只有一个
/// Stateful overlay，因此任何时刻最多只有一个框选框和一组动作按钮。
/// 框选矩形使用 viewer 坐标，可以直接跨过相邻 PDF 页；结束拖拽后再把
/// 这个矩形映射为它与各个 page layout 的交集 regions。
class PdfViewerAreaSelectionOverlay extends StatefulWidget {
  const PdfViewerAreaSelectionOverlay({
    super.key,
    required this.controller,
    required this.viewportSize,
    required this.onSelectionChanged,
    required this.onActionSelected,
    this.avoidTopRightControls = false,
  });

  final PdfViewerController controller;
  final Size viewportSize;
  final ValueChanged<PdfAiSelection?> onSelectionChanged;
  final ValueChanged<AiToolAction> onActionSelected;
  final bool avoidTopRightControls;

  @override
  State<PdfViewerAreaSelectionOverlay> createState() =>
      _PdfViewerAreaSelectionOverlayState();
}

class _PdfViewerAreaSelectionOverlayState
    extends State<PdfViewerAreaSelectionOverlay> {
  Rect? _dragRect;
  Rect? _selectedRect;
  Offset? _dragStart;
  Offset? _dragPointerOffset;
  DragMode _dragMode = DragMode.none;

  @override
  void didUpdateWidget(covariant PdfViewerAreaSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.viewportSize != widget.viewportSize) {
      final bool hadCommittedSelection = _selectedRect != null;
      _resetSelectionState();
      if (hadCommittedSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onSelectionChanged(null);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Rect? selectedRect = _selectedRect;
    final Offset? toolbarPosition = selectedRect == null
        ? null
        : _resolveToolbarPosition(context, selectedRect);

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: _handleTapDown,
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            onPanCancel: _handlePanCancel,
            child: CustomPaint(
              painter: _SelectionRectPainter(rect: _dragRect),
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tooltipBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '拖拽框选 PDF 区域',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selectedRect != null)
            _SelectionActionToolbar(
              rect: selectedRect,
              viewportSize: widget.viewportSize,
              screenAwarePosition: toolbarPosition,
              onTranslate: () {
                widget.onActionSelected(AiToolAction.translate);
                _clearSelection();
              },
              onExplain: () {
                widget.onActionSelected(AiToolAction.explain);
                _clearSelection();
              },
              onDeepDive: () {
                widget.onActionSelected(AiToolAction.deepDive);
                _clearSelection();
              },
            ),
        ],
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    final Rect? selectedRect = _selectedRect;
    if (selectedRect == null || selectedRect.contains(details.localPosition)) {
      return;
    }
    _clearSelection();
  }

  void _handlePanStart(DragStartDetails details) {
    final Offset point = _clampToViewport(details.localPosition);
    final Rect? selectedRect = _selectedRect;
    if (selectedRect != null && selectedRect.contains(point)) {
      setState(() {
        _dragMode = DragMode.move;
        _dragPointerOffset = point - selectedRect.topLeft;
        _dragRect = selectedRect;
      });
      return;
    }

    setState(() {
      _dragMode = DragMode.create;
      _dragStart = point;
      _dragRect = Rect.fromPoints(point, point);
      _selectedRect = null;
    });
    // 开始新的拖拽时立即清掉旧的业务 selection，保证全局只有一份。
    widget.onSelectionChanged(null);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragMode == DragMode.none) return;

    if (_dragMode == DragMode.move) {
      final Rect? currentRect = _dragRect;
      final Offset? pointerOffset = _dragPointerOffset;
      if (currentRect == null || pointerOffset == null) return;
      final Offset point = _clampToViewport(details.localPosition);
      final Offset topLeft = _clampTopLeft(
        point - pointerOffset,
        currentRect.size,
      );
      setState(() {
        _dragRect = topLeft & currentRect.size;
      });
      return;
    }

    final Offset? start = _dragStart;
    if (start == null) return;
    final Offset point = _clampToViewport(details.localPosition);
    setState(() {
      _dragRect = Rect.fromPoints(start, point);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    final Rect? rect = _dragRect;
    _dragStart = null;
    _dragPointerOffset = null;
    _dragMode = DragMode.none;

    if (rect == null || rect.width < 12 || rect.height < 12) {
      _clearSelection();
      return;
    }

    final List<PdfAiSelectionRegion> regions = _regionsForViewerRect(rect);
    if (regions.isEmpty) {
      _clearSelection();
      return;
    }

    setState(() {
      _selectedRect = rect;
      _dragRect = rect;
    });
    widget.onSelectionChanged(PdfAiSelection.regions(regions: regions));
  }

  void _handlePanCancel() {
    final Rect? selectedRect = _selectedRect;
    setState(() {
      _dragRect = selectedRect;
      _dragStart = null;
      _dragPointerOffset = null;
      _dragMode = DragMode.none;
    });
    if (selectedRect == null) {
      widget.onSelectionChanged(null);
    }
  }

  void _clearSelection({bool notify = true}) {
    final bool hadCommittedSelection = _selectedRect != null;
    if (mounted) {
      setState(_resetSelectionState);
    }
    if (notify && hadCommittedSelection) {
      widget.onSelectionChanged(null);
    }
  }

  void _resetSelectionState() {
    _selectedRect = null;
    _dragRect = null;
    _dragStart = null;
    _dragPointerOffset = null;
    _dragMode = DragMode.none;
  }

  Offset _clampToViewport(Offset point) {
    return Offset(
      point.dx.clamp(0, widget.viewportSize.width),
      point.dy.clamp(0, widget.viewportSize.height),
    );
  }

  Offset _clampTopLeft(Offset topLeft, Size size) {
    return Offset(
      topLeft.dx.clamp(0, math.max(0, widget.viewportSize.width - size.width)),
      topLeft.dy.clamp(0, math.max(0, widget.viewportSize.height - size.height)),
    );
  }

  /// 将 viewer-local 的一个矩形映射为与多个 PDF 页的交集。
  /// pageLayouts 使用 PDF document layout 坐标（72dpi），因此无需再除 zoom。
  List<PdfAiSelectionRegion> _regionsForViewerRect(Rect viewerRect) {
    final Offset? globalTopLeft = widget.controller.localToGlobal(
      viewerRect.topLeft,
    );
    final Offset? globalBottomRight = widget.controller.localToGlobal(
      viewerRect.bottomRight,
    );
    if (globalTopLeft == null || globalBottomRight == null) {
      return const <PdfAiSelectionRegion>[];
    }

    final Offset? documentTopLeft = widget.controller.globalToDocument(
      globalTopLeft,
    );
    final Offset? documentBottomRight = widget.controller.globalToDocument(
      globalBottomRight,
    );
    if (documentTopLeft == null || documentBottomRight == null) {
      return const <PdfAiSelectionRegion>[];
    }

    final Rect documentRect = Rect.fromLTRB(
      math.min(documentTopLeft.dx, documentBottomRight.dx),
      math.min(documentTopLeft.dy, documentBottomRight.dy),
      math.max(documentTopLeft.dx, documentBottomRight.dx),
      math.max(documentTopLeft.dy, documentBottomRight.dy),
    );

    final List<Rect> pageLayouts = widget.controller.layout.pageLayouts;
    final List<PdfPage> pages = widget.controller.pages;
    final int count = math.min(pageLayouts.length, pages.length);
    final List<PdfAiSelectionRegion> regions = <PdfAiSelectionRegion>[];

    for (int index = 0; index < count; index++) {
      final Rect pageLayout = pageLayouts[index];
      final Rect intersection = documentRect.intersect(pageLayout);
      if (intersection.width <= 0 || intersection.height <= 0) continue;

      final PdfPage page = pages[index];
      final Rect inPage = intersection.shift(-pageLayout.topLeft);
      final double left = inPage.left.clamp(0, page.width);
      final double right = inPage.right.clamp(0, page.width);
      final double visualTop = inPage.top.clamp(0, page.height);
      final double visualBottom = inPage.bottom.clamp(0, page.height);
      if (right <= left || visualBottom <= visualTop) continue;

      regions.add(
        PdfAiSelectionRegion(
          pageNumber: index + 1,
          bounds: PdfRect(
            left,
            page.height - visualTop,
            right,
            page.height - visualBottom,
          ),
        ),
      );
    }

    return regions;
  }

  Offset? _resolveToolbarPosition(BuildContext context, Rect rect) {
    final Offset? globalTopLeft = widget.controller.localToGlobal(rect.topLeft);
    final Offset? globalBottomRight = widget.controller.localToGlobal(
      rect.bottomRight,
    );
    if (globalTopLeft == null || globalBottomRight == null) return null;

    final Rect selectionGlobalRect = Rect.fromLTRB(
      math.min(globalTopLeft.dx, globalBottomRight.dx),
      math.min(globalTopLeft.dy, globalBottomRight.dy),
      math.max(globalTopLeft.dx, globalBottomRight.dx),
      math.max(globalTopLeft.dy, globalBottomRight.dy),
    );

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    const double screenMargin = 12;
    final Rect viewportGlobalRect = Rect.fromLTRB(
      mediaQuery.padding.left + screenMargin,
      mediaQuery.padding.top + screenMargin,
      mediaQuery.size.width - mediaQuery.padding.right - screenMargin,
      mediaQuery.size.height - mediaQuery.padding.bottom - screenMargin,
    );

    Rect? avoidGlobalRect;
    if (widget.avoidTopRightControls) {
      const double reservedWidth = 190;
      const double reservedHeight = 68;
      final double reservedLeft = (viewportGlobalRect.right - reservedWidth)
          .clamp(viewportGlobalRect.left, viewportGlobalRect.right);
      final double reservedBottom =
          (viewportGlobalRect.top + reservedHeight).clamp(
            viewportGlobalRect.top,
            viewportGlobalRect.bottom,
          );
      avoidGlobalRect = Rect.fromLTRB(
        reservedLeft,
        viewportGlobalRect.top,
        viewportGlobalRect.right,
        reservedBottom,
      );
    }

    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: selectionGlobalRect,
          viewportGlobalRect: viewportGlobalRect,
          avoidGlobalRect: avoidGlobalRect,
          screenHeight: mediaQuery.size.height,
        );
    return widget.controller.globalToLocal(placement.globalRect.topLeft);
  }
}

class _SelectionActionToolbar extends StatelessWidget {
  const _SelectionActionToolbar({
    required this.rect,
    required this.viewportSize,
    required this.screenAwarePosition,
    required this.onTranslate,
    required this.onExplain,
    required this.onDeepDive,
  });

  final Rect rect;
  final Size viewportSize;
  final Offset? screenAwarePosition;
  final VoidCallback onTranslate;
  final VoidCallback onExplain;
  final VoidCallback onDeepDive;

  @override
  Widget build(BuildContext context) {
    final Offset position = screenAwarePosition ?? _fallbackViewerPosition();
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xE61D4ED8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x667DA2E8)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _SelectionActionButton(label: '翻译', onPressed: onTranslate),
                  const _Divider(),
                  _SelectionActionButton(label: '解释', onPressed: onExplain),
                  const _Divider(),
                  _SelectionActionButton(label: '深度理解', onPressed: onDeepDive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _fallbackViewerPosition() {
    const double toolbarWidth = 256;
    const double toolbarHeight = 38;
    const double gap = 10;
    final double left = ((viewportSize.width - toolbarWidth) / 2).clamp(
      0,
      math.max(0, viewportSize.width - toolbarWidth),
    );
    double top = rect.bottom + gap;
    if (top + toolbarHeight > viewportSize.height) {
      top = rect.top - toolbarHeight - gap;
    }
    top = top.clamp(0, math.max(0, viewportSize.height - toolbarHeight));
    return Offset(left, top);
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 6,
        child: VerticalDivider(width: 1, color: Color(0x40FFFFFF)),
      ),
    );
  }
}

class _SelectionActionButton extends StatelessWidget {
  const _SelectionActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0x1FFFFFFF),
        highlightColor: const Color(0x2EFFFFFF),
        child: SizedBox(
          width: 74,
          height: 30,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionRectPainter extends CustomPainter {
  const _SelectionRectPainter({required this.rect});

  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect? value = rect;
    if (value == null || value.isEmpty) return;
    canvas.drawRect(value, Paint()..color = AppColors.selectionFill);
    canvas.drawRect(
      value,
      Paint()
        ..color = AppColors.selectionStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectionRectPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
