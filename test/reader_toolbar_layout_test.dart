import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plume_pdf/app/modules/home/views/widgets/reader_toolbar.dart';
import 'package:plume_pdf/app/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final double width in <double>[800, 1280, 1920]) {
    testWidgets('工具栏在 $width 宽度下保持对齐且不溢出', (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await tester.binding.setSurfaceSize(Size(width, 80));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderToolbar(
              fileName: 'sample.pdf',
              hasDocument: true,
              pageController: TextEditingController(text: '2'),
              currentPage: 2,
              pageCount: 143,
              zoomLabel: '104%',
              sidebarVisible: false,
              spreadMode: false,
              aiSelectionMode: false,
              aiSidebarVisible: false,
              onOpenFile: _noop,
              onPreviousPage: _noop,
              onNextPage: _noop,
              onPageSubmitted: _noopString,
              onZoomOut: _noop,
              onZoomIn: _noop,
              onFitWidth: _noop,
              onActualSize: _noop,
              onToggleSidebar: _noop,
              onToggleSpreadMode: _noop,
              onToggleAiSelectionMode: _noop,
              onToggleAiSidebar: _noop,
              onShowRecentFiles: _noop,
              onSetBackgroundTheme: (_) {},
              backgroundTheme: PdfBackgroundTheme.normal,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('侧边栏'), findsOneWidget);
      expect(find.byTooltip('打开文件'), findsOneWidget);
      expect(find.text('sample.pdf'), findsNothing);

      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });
  }
}

void _noop() {}

void _noopString(String _) {}
