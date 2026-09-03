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
          onEscape: () {
            escapeCalls++;
            return true;
          },
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

  testWidgets('Escape key down reaches reader before a descendant consumes it', (
    WidgetTester tester,
  ) async {
    final FocusNode childFocusNode = FocusNode();
    addTearDown(childFocusNode.dispose);
    int escapeCalls = 0;
    int descendantKeyDownCalls = 0;

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
          onEscape: () {
            escapeCalls++;
            return true;
          },
          child: Focus(
            focusNode: childFocusNode,
            onKeyEvent: (_, KeyEvent event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                descendantKeyDownCalls++;
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
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
    expect(descendantKeyDownCalls, 0);
  });

  testWidgets('Escape stays available to descendants when reader does nothing', (
    WidgetTester tester,
  ) async {
    final FocusNode childFocusNode = FocusNode();
    addTearDown(childFocusNode.dispose);
    int readerCalls = 0;
    int descendantCalls = 0;

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
          onEscape: () {
            readerCalls++;
            return false;
          },
          child: Focus(
            focusNode: childFocusNode,
            onKeyEvent: (_, KeyEvent event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                descendantCalls++;
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    childFocusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(readerCalls, 1);
    expect(descendantCalls, 1);
  });

  testWidgets('disposing ReaderShortcuts removes the early Escape handler', (
    WidgetTester tester,
  ) async {
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
          onEscape: () {
            escapeCalls++;
            return true;
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.expand()));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(escapeCalls, 0);
  });
}

void _noop() {}
