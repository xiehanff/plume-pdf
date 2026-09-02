import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plume_pdf/app/modules/home/views/widgets/reader_shortcuts.dart';

void main() {
  testWidgets('Escape reaches reader handler while a descendant owns focus', (
    WidgetTester tester,
  ) async {
    final FocusNode childFocusNode = FocusNode();
    addTearDown(childFocusNode.dispose);
    int escapeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderShortcuts(
          onOpenFile: _noop,
          onPreviousPage: _noop,
          onNextPage: _noop,
          onZoomIn: _noop,
          onZoomOut: _noop,
          onActualSize: _noop,
          onToggleSidebar: _noop,
          onEscape: () => escapeCalls++,
          child: Focus(
            focusNode: childFocusNode,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    childFocusNode.requestFocus();
    await tester.pump();
    expect(childFocusNode.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(escapeCalls, 1);
  });
}

void _noop() {}
