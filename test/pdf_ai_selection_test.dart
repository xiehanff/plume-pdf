import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_ai_selection.dart';

void main() {
  test('单页 selection 保持原有 pageNumber 和 bounds 兼容访问', () {
    final PdfAiSelection selection = PdfAiSelection.area(
      pageNumber: 3,
      bounds: const PdfRect(10, 80, 100, 20),
    );

    expect(selection.regions, hasLength(1));
    expect(selection.pageNumber, 3);
    expect(selection.bounds.left, 10);
    expect(selection.spansMultiplePages, isFalse);
    expect(selection.summary, contains('第 3 页'));
  });

  test('跨页 selection 是一份 selection 多个 page regions', () {
    final PdfAiSelection selection = PdfAiSelection.regions(
      regions: const <PdfAiSelectionRegion>[
        PdfAiSelectionRegion(
          pageNumber: 4,
          bounds: PdfRect(20, 120, 180, 0),
        ),
        PdfAiSelectionRegion(
          pageNumber: 5,
          bounds: PdfRect(20, 800, 180, 620),
        ),
      ],
    );

    expect(selection.regions, hasLength(2));
    expect(selection.firstPageNumber, 4);
    expect(selection.lastPageNumber, 5);
    expect(selection.spansMultiplePages, isTrue);
    expect(selection.summary, contains('第 4-5 页'));
  });

  test('copyWith 写入提取文本时保留全部跨页 regions', () {
    final PdfAiSelection selection = PdfAiSelection.regions(
      regions: const <PdfAiSelectionRegion>[
        PdfAiSelectionRegion(pageNumber: 1, bounds: PdfRect(0, 100, 50, 0)),
        PdfAiSelectionRegion(pageNumber: 2, bounds: PdfRect(0, 100, 50, 0)),
      ],
    );

    final PdfAiSelection updated = selection.copyWith(extractedText: '跨页正文');

    expect(updated.regions, hasLength(2));
    expect(updated.firstPageNumber, 1);
    expect(updated.lastPageNumber, 2);
    expect(updated.extractedText, '跨页正文');
  });
}
