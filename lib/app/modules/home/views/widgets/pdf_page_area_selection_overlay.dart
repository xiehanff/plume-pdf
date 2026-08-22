import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../theme/app_colors.dart';
import '../../models/pdf_ai_selection.dart';
import '../../services/deepseek_service.dart';

enum DragMode { none, create, move }

class PdfPageAreaSelectionOverlay extends StatefulWidget {
  const PdfPageAreaSelectionOverlay({
    super.key,
    required this.page,
    required this.pageRect,
    required this.aiSelectionEnabled,
    required this.onSelectionChanged,
    required this.onActionSelected,
  });

  final PdfPage page;
  final Rect pageRect;
  final bool aiSelectionEnabled;
  final ValueChanged<PdfAiSelection?> onSelectionChanged;
  final ValueChanged<AiToolAction> onActionSelected;

  @override
  State<PdfPageAreaSelectionOverlay> createState() =>
      _PdfPageAreaSelectionOverlayState();
}

class _PdfPageAreaSelectionOverlayState
    extends State<PdfPageAreaSelectionOverlay> {
  Rect? _dragRect;
  Rect? _selectedRect;
  Offset? _dragStart;
  Offset? _dragPointerOffset;
  DragMode _dragMode = DragMode.none;

  @override
  void didUpdateWidget(covariant PdfPageAreaSelectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.pageNumber != widget.page.pageNumber ||
        oldWidget.pageRect != widget.pageRect) {
      _dragRect = null;
      _selectedRect = null;
      _dragStart = null;
    } else if (!widget.aiSelectionEnabled && _dragRect != null) {
      setState(() {
        _dragRect = null;
        _selectedRect = null;
        _dragStart = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.aiSelectionEnabled && _dragRect == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: _handleTapDown,
            onPanStart: widget.aiSelectionEnabled ? _handlePanStart : null,
            onPanUpdate: widget.aiSelectionEnabled ? _handlePanUpdate : null,
            onPanEnd: widget.aiSelectionEnabled ? _handlePanEnd : null,
            onPanCancel: _handlePanCancel,
            child: CustomPaint(
              painter: _SelectionRectPainter(rect: _dragRect),
              child: widget.aiSelectionEnabled
                  ? Align(
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
                          '拖拽框选图片区域',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 11),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          if (_selectedRect != null)
            _SelectionActionToolbar(
              rect: _selectedRect!,
              pageSize: widget.pageRect.size,
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

  void _clearSelection() {
    setState(() {
      _selectedRect = null;
      _dragRect = null;
      _dragStart = null;
      _dragPointerOffset = null;
      _dragMode = DragMode.none;
    });
    widget.onSelectionChanged(null);
  }

  void _notifySelectionChanged(Rect rect) {
    widget.onSelectionChanged(
      PdfAiSelection.area(
        pageNumber: widget.page.pageNumber,
        bounds: _toPdfRect(rect),
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    final Rect? selectedRect = _selectedRect;
    if (selectedRect == null) {
      return;
    }
    if (selectedRect.contains(details.localPosition)) {
      return;
    }
    _clearSelection();
  }

  void _handlePanStart(DragStartDetails details) {
    final Offset point = _clampToPage(details.localPosition);
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
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragMode == DragMode.none) {
      return;
    }
    if (_dragMode == DragMode.move) {
      final Rect? currentRect = _dragRect;
      final Offset? pointerOffset = _dragPointerOffset;
      if (currentRect == null || pointerOffset == null) {
        return;
      }
      final Offset point = _clampToPage(details.localPosition);
      final Offset topLeft = _clampTopLeft(
        point - pointerOffset,
        currentRect.size,
      );
      setState(() {
        _dragRect = topLeft & currentRect.size;
      });
      return;
    }
    if (_dragStart == null) {
      return;
    }
    final Offset point = _clampToPage(details.localPosition);
    setState(() {
      _dragRect = Rect.fromPoints(_dragStart!, point);
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

    setState(() {
      _selectedRect = rect;
      _dragRect = rect;
    });
    _notifySelectionChanged(rect);
  }

  void _handlePanCancel() {
    if (_dragRect == null && _dragStart == null) {
      return;
    }
    final Rect? selectedRect = _selectedRect;
    setState(() {
      _dragRect = selectedRect;
      _dragPointerOffset = null;
      _dragStart = null;
      _dragMode = DragMode.none;
    });
    if (selectedRect == null) {
      widget.onSelectionChanged(null);
    }
  }

  Offset _clampToPage(Offset point) {
    return Offset(
      point.dx.clamp(0, widget.pageRect.width),
      point.dy.clamp(0, widget.pageRect.height),
    );
  }

  Offset _clampTopLeft(Offset topLeft, Size size) {
    final double maxLeft = widget.pageRect.width - size.width;
    final double maxTop = widget.pageRect.height - size.height;
    return Offset(
      topLeft.dx.clamp(0, maxLeft < 0 ? 0 : maxLeft),
      topLeft.dy.clamp(0, maxTop < 0 ? 0 : maxTop),
    );
  }

  PdfRect _toPdfRect(Rect rect) {
    final double scale = widget.pageRect.height / widget.page.height;
    final double left = rect.left / scale;
    final double right = rect.right / scale;
    final double top = widget.page.height - (rect.top / scale);
    final double bottom = widget.page.height - (rect.bottom / scale);
    return PdfRect(left, top, right, bottom);
  }
}

class _SelectionActionToolbar extends StatelessWidget {
  const _SelectionActionToolbar({
    required this.rect,
    required this.pageSize,
    required this.onTranslate,
    required this.onExplain,
    required this.onDeepDive,
  });

  final Rect rect;
  final Size pageSize;
  final VoidCallback onTranslate;
  final VoidCallback onExplain;
  final VoidCallback onDeepDive;

  @override
  Widget build(BuildContext context) {
    const double toolbarHeight = 40;
    const double toolbarWidth = 242;
    const double gap = 10;
    final double preferredLeft = rect.center.dx - (toolbarWidth / 2);
    final double clampedLeft = preferredLeft.clamp(
      12,
      (pageSize.width - toolbarWidth - 12).clamp(12, double.infinity),
    );
    double top = rect.bottom + gap;
    if (top + toolbarHeight > pageSize.height - 12) {
      top = rect.top - toolbarHeight - gap;
    }
    top = top.clamp(12, (pageSize.height - toolbarHeight - 12).clamp(12, double.infinity));

    return Positioned(
      left: clampedLeft,
      top: top,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xA62C5B9E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x597FA8D8)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _SelectionActionButton(
                    label: '翻译',
                    onPressed: onTranslate,
                  ),
                  const SizedBox(width: 6),
                  _SelectionActionButton(
                    label: '解释',
                    onPressed: onExplain,
                  ),
                  const SizedBox(width: 6),
                  _SelectionActionButton(
                    label: '深度理解',
                    onPressed: onDeepDive,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionActionButton extends StatelessWidget {
  const _SelectionActionButton({
    required this.label,
    required this.onPressed,
  });

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
    if (value == null || value.isEmpty) {
      return;
    }

    canvas.drawRect(
      value,
      Paint()..color = AppColors.selectionFill,
    );
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
