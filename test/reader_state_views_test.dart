import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plume_pdf/app/modules/home/models/pdf_recent_file.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/empty_reader_view.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/error_reader_view.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/recent_files_grid.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/reader_shortcut_platform.dart';

void main() {
  testWidgets('空态在 macOS 显示 Command 快捷键提示', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      MaterialApp(
        home: EmptyReaderView(onOpenFile: () {}),
      ),
    );

    expect(find.text('打开本地 PDF'), findsOneWidget);
    expect(find.text('选择 PDF 文件'), findsOneWidget);
    expect(find.text('快捷键：Command + O'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('快捷键修饰键文案随平台变化', (WidgetTester tester) async {
    expect(primaryShortcutModifierLabel(TargetPlatform.macOS), 'Command');
    expect(primaryShortcutModifierLabel(TargetPlatform.windows), 'Ctrl');
  });

  testWidgets('错误态在 Windows 显示 Ctrl 快捷键提示', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(
      const MaterialApp(
        home: ErrorReaderView(
          message: '测试错误',
          onRetry: _noop,
        ),
      ),
    );

    expect(find.text('文档打开失败'), findsOneWidget);
    expect(find.text('测试错误'), findsOneWidget);
    expect(find.text('重新选择文件'), findsOneWidget);
    expect(find.text('快捷键：Ctrl + O'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('最近阅读展示添加时间和无效文件菜单', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecentFilesGrid(
          files: <PdfRecentFile>[
            PdfRecentFile(
              path: r'C:\docs\sample.pdf',
              name: 'sample.pdf',
              lastOpenedAt: DateTime(2026, 6, 20, 0, 30),
            ),
          ],
          unavailableFilePaths: const <String>{r'C:\docs\sample.pdf'},
          onOpenFile: () {},
          onRecentFileTap: (_) {},
          onDeleteRecentFile: (_) {},
          onRecoverRecentFile: (_) {},
        ),
      ),
    );

    expect(find.text('添加于 2026-06-20 00:30'), findsOneWidget);
    expect(find.text('无法访问'), findsOneWidget);
    expect(find.byTooltip('删除记录'), findsOneWidget);
    expect(find.byTooltip('无效记录操作'), findsOneWidget);
  });
}

void _noop() {}
