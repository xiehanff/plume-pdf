import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/selection_toolbar_placement.dart';

void main() {
  const Rect viewport = Rect.fromLTRB(12, 32, 388, 788);

  test('选区靠近屏幕顶部时工具条放在下方', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(80, 50, 260, 120),
          viewportGlobalRect: viewport,
        );

    expect(placement.placeBelow, isTrue);
    expect(placement.centeredInSelection, isFalse);
    expect(placement.globalRect.top, 130);
    expect(placement.globalRect.top, greaterThanOrEqualTo(viewport.top));
    expect(placement.globalRect.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  test('选区靠近屏幕底部时工具条放在上方', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(80, 700, 260, 770),
          viewportGlobalRect: viewport,
        );

    expect(placement.placeBelow, isFalse);
    expect(placement.centeredInSelection, isFalse);
    expect(placement.globalRect.bottom, 690);
    expect(placement.globalRect.top, greaterThanOrEqualTo(viewport.top));
    expect(placement.globalRect.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  test('上下都能放时选择真实可用空间更大的一侧', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(80, 220, 260, 300),
          viewportGlobalRect: viewport,
        );

    expect(placement.placeBelow, isTrue);
    expect(placement.centeredInSelection, isFalse);
    expect(placement.globalRect.top, 310);
  });

  test('工具条 X 永远按屏幕可视区水平中心对齐', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(350, 250, 520, 330),
          viewportGlobalRect: viewport,
        );

    expect(placement.globalRect.center.dx, viewport.center.dx);
    expect(placement.globalRect.left, 72);
    expect(placement.globalRect.right, 328);
  });

  test('上下空间都低于屏幕高度 20% 时改为选区中心定位', () {
    const Rect selection = Rect.fromLTRB(170, 35, 290, 760);
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: selection,
          viewportGlobalRect: viewport,
        );

    expect(placement.centeredInSelection, isTrue);
    expect(placement.globalRect.center, selection.center);
    expect(placement.globalRect.left, greaterThanOrEqualTo(viewport.left));
    expect(placement.globalRect.right, lessThanOrEqualTo(viewport.right));
    expect(placement.globalRect.top, greaterThanOrEqualTo(viewport.top));
    expect(placement.globalRect.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  test('20% 最低阈值使用显式屏幕高度计算', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(40, 180, 360, 650),
          viewportGlobalRect: viewport,
          screenHeight: 1000,
        );

    // 上方 148、下方 138，均低于 1000 * 20% = 200。
    expect(placement.centeredInSelection, isTrue);
    expect(placement.globalRect.center.dx, viewport.center.dx);
    expect(placement.globalRect.center.dy, 415);
  });

  test('首选位置与右上角 AI 模式区域冲突时只切换 Y，不改变屏幕居中 X', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(220, 100, 380, 780),
          viewportGlobalRect: viewport,
          avoidGlobalRect: const Rect.fromLTRB(190, 32, 388, 105),
          minimumSideSpaceFraction: 0,
        );

    expect(placement.placeBelow, isTrue);
    expect(placement.globalRect.center.dx, viewport.center.dx);
    expect(
      placement.globalRect.overlaps(
        const Rect.fromLTRB(182, 24, 396, 113),
      ),
      isFalse,
    );
    expect(placement.globalRect.bottom, lessThanOrEqualTo(viewport.bottom));
  });
}
