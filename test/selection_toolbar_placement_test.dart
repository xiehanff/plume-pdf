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
    expect(placement.globalRect.top, 310);
  });

  test('横向位置按屏幕可视区 clamp，不依赖 PDF 页面宽度', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(350, 250, 520, 330),
          viewportGlobalRect: viewport,
        );

    expect(placement.globalRect.right, viewport.right);
    expect(placement.globalRect.left, viewport.right - 256);
  });

  test('选区几乎占满屏幕时仍保证工具条留在可点击区域', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(40, 35, 360, 760),
          viewportGlobalRect: viewport,
        );

    expect(placement.globalRect.left, greaterThanOrEqualTo(viewport.left));
    expect(placement.globalRect.right, lessThanOrEqualTo(viewport.right));
    expect(placement.globalRect.top, greaterThanOrEqualTo(viewport.top));
    expect(placement.globalRect.bottom, lessThanOrEqualTo(viewport.bottom));
  });

  test('首选位置与右上角 AI 模式区域冲突时切换到另一侧', () {
    final SelectionToolbarPlacement placement =
        resolveSelectionToolbarPlacement(
          selectionGlobalRect: const Rect.fromLTRB(220, 100, 380, 780),
          viewportGlobalRect: viewport,
          avoidGlobalRect: const Rect.fromLTRB(190, 32, 388, 105),
        );

    expect(placement.placeBelow, isTrue);
    expect(
      placement.globalRect.overlaps(
        const Rect.fromLTRB(182, 24, 396, 113),
      ),
      isFalse,
    );
    expect(placement.globalRect.bottom, lessThanOrEqualTo(viewport.bottom));
  });
}
