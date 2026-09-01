import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

@immutable
class SelectionToolbarPlacement {
  const SelectionToolbarPlacement({
    required this.globalRect,
    required this.placeBelow,
  });

  final Rect globalRect;
  final bool placeBelow;
}

/// 根据选区在屏幕中的真实位置决定悬浮工具条位置。
///
/// 这里刻意只使用 viewport / selection 的 global rect，不参考 PDF 页号、
/// 页面高度或选区位于页面的哪一半。这样 PDF 页面即使只露出一部分、
/// 处于缩放/平移状态，工具条仍以用户当前真正可见的屏幕空间为准。
SelectionToolbarPlacement resolveSelectionToolbarPlacement({
  required Rect selectionGlobalRect,
  required Rect viewportGlobalRect,
  Rect? avoidGlobalRect,
  Size toolbarSize = const Size(256, 40),
  double gap = 10,
}) {
  final double maxLeft = viewportGlobalRect.right - toolbarSize.width;
  final double preferredLeft =
      selectionGlobalRect.center.dx - toolbarSize.width / 2;
  final double left = preferredLeft.clamp(
    viewportGlobalRect.left,
    maxLeft < viewportGlobalRect.left ? viewportGlobalRect.left : maxLeft,
  );

  final double aboveSpace =
      selectionGlobalRect.top - viewportGlobalRect.top;
  final double belowSpace =
      viewportGlobalRect.bottom - selectionGlobalRect.bottom;
  final double requiredSpace = toolbarSize.height + gap;
  final bool aboveFits = aboveSpace >= requiredSpace;
  final bool belowFits = belowSpace >= requiredSpace;

  bool placeBelow;
  if (belowFits != aboveFits) {
    placeBelow = belowFits;
  } else {
    // 两侧都能完整容纳，或者两侧都不足时，都选择真实可用空间更大的一侧。
    placeBelow = belowSpace >= aboveSpace;
  }

  Rect candidate = _candidateRect(
    selectionGlobalRect: selectionGlobalRect,
    viewportGlobalRect: viewportGlobalRect,
    toolbarSize: toolbarSize,
    gap: gap,
    left: left,
    placeBelow: placeBelow,
  );
  Rect alternate = _candidateRect(
    selectionGlobalRect: selectionGlobalRect,
    viewportGlobalRect: viewportGlobalRect,
    toolbarSize: toolbarSize,
    gap: gap,
    left: left,
    placeBelow: !placeBelow,
  );

  final Rect? avoid = avoidGlobalRect?.inflate(8);
  if (avoid != null && candidate.overlaps(avoid)) {
    if (!alternate.overlaps(avoid)) {
      candidate = alternate;
      placeBelow = !placeBelow;
    } else {
      candidate = _shiftHorizontallyAwayFromAvoidRect(
        candidate: candidate,
        viewport: viewportGlobalRect,
        avoid: avoid,
        gap: gap,
      );
    }
  }

  return SelectionToolbarPlacement(
    globalRect: candidate,
    placeBelow: placeBelow,
  );
}

Rect _candidateRect({
  required Rect selectionGlobalRect,
  required Rect viewportGlobalRect,
  required Size toolbarSize,
  required double gap,
  required double left,
  required bool placeBelow,
}) {
  final double preferredTop = placeBelow
      ? selectionGlobalRect.bottom + gap
      : selectionGlobalRect.top - toolbarSize.height - gap;
  final double maxTop = viewportGlobalRect.bottom - toolbarSize.height;
  final double top = preferredTop.clamp(
    viewportGlobalRect.top,
    maxTop < viewportGlobalRect.top ? viewportGlobalRect.top : maxTop,
  );
  return Rect.fromLTWH(left, top, toolbarSize.width, toolbarSize.height);
}

Rect _shiftHorizontallyAwayFromAvoidRect({
  required Rect candidate,
  required Rect viewport,
  required Rect avoid,
  required double gap,
}) {
  final List<double> options = <double>[];
  final double leftOfAvoid = avoid.left - gap - candidate.width;
  if (leftOfAvoid >= viewport.left) {
    options.add(leftOfAvoid);
  }
  final double rightOfAvoid = avoid.right + gap;
  if (rightOfAvoid + candidate.width <= viewport.right) {
    options.add(rightOfAvoid);
  }
  if (options.isEmpty) {
    return candidate;
  }

  options.sort(
    (double a, double b) =>
        (a - candidate.left).abs().compareTo((b - candidate.left).abs()),
  );
  return Rect.fromLTWH(
    options.first,
    candidate.top,
    candidate.width,
    candidate.height,
  );
}
