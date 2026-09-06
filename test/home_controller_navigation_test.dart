import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/controllers/home_controller.dart';
import 'package:plume_pdf/app/modules/home/models/pdf_reader_state.dart';
import 'package:plume_pdf/app/modules/pdf_ai/models/pdf_ai_panel_state.dart';
import 'package:plume_pdf/app/modules/reader/models/pdf_outline_entry.dart';

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

  testWidgets('missing PDF does not advance document or AI preflight lifecycle', (
    WidgetTester tester,
  ) async {
    final HomeController controller = HomeController();
    const PdfAiPanelState runningPreflight = PdfAiPanelState(
      apiKey: 'cached-key',
      loading: true,
    );
    controller.state = const PdfReaderState(
      filePath: '/tmp/current-reader-document.pdf',
      currentPage: 4,
      pageCount: 12,
      aiPanelState: runningPreflight,
    );

    const String missingPath =
        '/tmp/plume_pdf_round5_missing_94f13f6238d84eb9a8d13d7cc31d7f8f.pdf';
    // openFilePath 会执行真实 dart:io File.exists；widget test 的 FakeAsync
    // 不推进真实文件 I/O，因此必须在 runAsync 区域执行。
    await tester.runAsync(() => controller.openFilePath(missingPath));

    // 打开失败只是当前操作失败，不应切走正在阅读的文档。
    expect(controller.state.filePath, '/tmp/current-reader-document.pdf');
    expect(controller.state.currentPage, 4);
    expect(controller.state.unavailableRecentFilePaths, contains(missingPath));
    expect(controller.state.errorMessage, '文件不存在，可能已经被移动或删除。');

    // 失败发生在文档切换正式开始之前，因此不应结束当前 PDF/OCR preflight，
    // 也不应重建 Host AI 状态。Package conversation generation 由
    // AiChatController 自己的生命周期测试覆盖。
    expect(controller.state.aiPanelState, same(runningPreflight));
    expect(controller.state.aiPanelState.apiKey, 'cached-key');
    expect(controller.state.aiPanelState.loading, isTrue);

    controller.onClose();
  });
}
