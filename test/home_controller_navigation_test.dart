import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/controllers/home_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_outline_entry.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_reader_state.dart';

void main() {
  testWidgets(
    'page callback updates page state and stale progress debounce is ignored',
    (WidgetTester tester) async {
      final HomeController controller = HomeController();
      controller.state = const PdfReaderState(
        filePath: '/tmp/a.pdf',
        currentPage: 1,
        pageCount: 10,
        outline: <PdfOutlineEntry>[
          PdfOutlineEntry(
            id: 'chapter-1',
            title: 'Chapter 1',
            pageNumber: 1,
            depth: 0,
          ),
          PdfOutlineEntry(
            id: 'chapter-2',
            title: 'Chapter 2',
            pageNumber: 3,
            depth: 0,
          ),
        ],
      );

      controller.onPageChanged(3);

      expect(controller.state.currentPage, 3);
      expect(controller.state.selectedOutlineId, 'chapter-2');
      expect(controller.pageTextController.text, '3');

      controller.showRecentFiles();
      await tester.pump(const Duration(milliseconds: 450));

      expect(controller.state.filePath, isNull);
      expect(controller.state.currentPage, 1);

      controller.onClose();
    },
  );
}
