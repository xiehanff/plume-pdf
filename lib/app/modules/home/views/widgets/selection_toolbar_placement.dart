import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

@immutable
class SelectionToolbarPlacement {
  const SelectionToolbarPlacement({
    required this.globalRect,
    required this.placeBelow,
    this.centeredInSelection = false,
  });

  final Rect globalRect;
  final bool placeBelow;

  /// 当选区上下两侧都小于屏幕高度的最小阈值时，不再把工具条硬塞到
  /// 选区外侧，而是放到选区垂直中心。此模式下 X 永远以屏幕中心为准。
  final bool centeredInSelection;
}

/// 根据选区在屏幕中的真实位置决定悬浮工具条位置。
///
/// 这里只使用 viewport / selection 的 global rect，不参考 PDF 页号、
/// 页面高度或选区位于页面的哪一半。工具条的 X 永远以屏幕可视区域
/// 水平中心对齐，只有 Y 根据选区上下空间变化。
///
/// 当选区上下剩余空间都不足屏幕高度的 [minimumSideSpaceFraction] 时，
/// 视为“选区几乎占满屏幕”。此时工具条直接放在选区垂直中心，避免
/// 继续 clamp 到屏幕顶/底边造成不可点击或与其他浮层重叠。
SelectionToolbarPlacement resolveSelectionToolbarPlacement({
  required Rect selectionGlobalRect,
  required Rect viewportGlobalRect,
  Rect? avoidGlobalRect,
  Size toolbarSize = const Size(256, 40),
  double gap = 10,
  double minimumSideSpaceFraction = 0.20,
  double? screenHeight,
}) {
  final double maxLeft = viewportGlobalRect.right - toolbarSize.width;
  final double preferredLeft =
      viewportGlobalRect.center.dx - toolbarSize.width / 2;
  final double left = preferredLeft.clamp(
    viewportGlobalRect.left,
    maxLeft < viewportGlobalRect.left ? viewportGlobalRect.left : maxLeft,
  );

  final double aboveSpace =
      selectionGlobalRect.top - viewportGlobalRect.top;
  final double belowSpace =
      viewportGlobalRect.bottom - selectionGlobalRect.bottom;
  final double minimumSideSpace =
      (screenHeight ?? viewportGlobalRect.height) * minimumSideSpaceFraction;

  // 选区几乎覆盖整个可视区域时，上下两边都不再具备稳定的浮层空间。
  // 这时不做 above/below clamp，直接把工具条放到选区中心；X 仍固定
  // 在屏幕中心，只让 Y 与选区中心发生关系。
  if (aboveSpace < minimumSideSpace && belowSpace < minimumSideSpace) {
    final double maxTop = viewportGlobalRect.bottom - toolbarSize.height;
    final double preferredTop =
        selectionGlobalRect.center.dy - toolbarSize.height / 2;
    final double top = preferredTop.clamp(
      viewportGlobalRect.top,
      maxTop < viewportGlobalRect.top ? viewportGlobalRect.top : maxTop,
    );
    return SelectionToolbarPlacement(
      globalRect: Rect.fromLTWH(
        left,
        top,
        toolbarSize.width,
        toolbarSize.height,
      ),
      placeBelow: false,
      centeredInSelection: true,
    );
  }

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
  final Rect alternate = _candidateRect(
    selectionGlobalRect: selectionGlobalRect,
    viewportGlobalRect: viewportGlobalRect,
    toolbarSize: toolbarSize,
    gap: gap,
    left: left,
    placeBelow: !placeBelow,
  );

  // X 必须始终屏幕居中，所以避让 AI 模式控件时只切换上下方向，
  // 不再横向挪动工具条。
  final Rect? avoid = avoidGlobalRect?.inflate(8);
  if (avoid != null && candidate.overlaps(avoid) && !alternate.overlaps(avoid)) {
    candidate = alternate;
    placeBelow = !placeBelow;
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
