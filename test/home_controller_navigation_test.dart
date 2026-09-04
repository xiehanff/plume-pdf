import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/controllers/home_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_outline_entry.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_reader_state.dart';

void main() {
  testWidgets(
    'page callback is source-bound and stale progress debounce is ignored',
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

      controller.onPageChanged('/tmp/a.pdf', 3);

      expect(controller.state.currentPage, 3);
      expect(controller.state.selectedOutlineId, 'chapter-2');
      expect(controller.pageTextController.text, '3');

      controller.state = controller.state.copyWith(
        filePath: '/tmp/b.pdf',
        currentPage: 1,
        selectedOutlineId: null,
      );
      controller.onPageChanged('/tmp/a.pdf', 5);

      expect(controller.state.filePath, '/tmp/b.pdf');
      expect(controller.state.currentPage, 1);
      expect(controller.state.selectedOutlineId, isNull);

      await tester.pump(const Duration(milliseconds: 450));

      expect(controller.state.filePath, '/tmp/b.pdf');
      expect(controller.state.currentPage, 1);

      controller.onClose();
    },
  );

  testWidgets('missing PDF does not advance document or AI session lifecycle', (
    WidgetTester tester,
  ) async {
    final HomeController controller = HomeController();
    controller.state = const PdfReaderState(
      filePath: '/tmp/current-reader-document.pdf',
      currentPage: 4,
      pageCount: 12,
    );

    const String missingPath =
        '/tmp/plume_pdf_round5_missing_94f13f6238d84eb9a8d13d7cc31d7f8f.pdf';
    await controller.openFilePath(missingPath);

    // 打开失败只是当前操作失败，不应切走正在阅读的文档。
    expect(controller.state.filePath, '/tmp/current-reader-document.pdf');
    expect(controller.state.currentPage, 4);
    expect(controller.state.unavailableRecentFilePaths, contains(missingPath));
    expect(controller.state.errorMessage, '文件不存在，可能已经被移动或删除。');

    // 如果失败路径错误地推进了 _aiSessionId，这里会得到 sessionId == 2。
    // 正确语义是失败尝试不算一次文档/AI 生命周期切换，因此下一次真实
    // “新会话”仍然从 0 递增到 1。
    controller.startNewAiSession();
    expect(controller.state.aiPanelState.sessionId, 1);

    controller.onClose();
  });
}
