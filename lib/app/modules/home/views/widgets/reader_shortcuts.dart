import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reader_shortcut_platform.dart';

class ReaderShortcuts extends StatefulWidget {
  const ReaderShortcuts({
    super.key,
    required this.onOpenFile,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onActualSize,
    required this.onToggleSidebar,
    required this.onEscape,
    required this.child,
  });

  final VoidCallback onOpenFile;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onActualSize;
  final VoidCallback onToggleSidebar;
  final VoidCallback onEscape;
  final Widget child;

  @override
  State<ReaderShortcuts> createState() => _ReaderShortcutsState();
}

class _ReaderShortcutsState extends State<ReaderShortcuts> {
  final FocusNode _readerFocusNode = FocusNode(debugLabel: 'ReaderShortcuts');

  @override
  void initState() {
    super.initState();
    // pdfrx puts its own Focus node around the viewer. On Linux that node can
    // consume the event before it bubbles to the Reader Focus node, so handle
    // Escape at the beginning of the focus dispatch while the Reader owns the
    // focus path.
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyKeyEvent);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyKeyEvent);
    _readerFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleEarlyKeyEvent(KeyEvent event) {
    if (!_readerFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }
    return _handleEscape(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  KeyEventResult _handleFocusKeyEvent(FocusNode _, KeyEvent event) {
    return _handleEscape(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  bool _handleEscape(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    widget.onEscape();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bool useMeta = usesMetaModifier();
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        SingleActivator(
          LogicalKeyboardKey.keyO,
          meta: useMeta,
          control: !useMeta,
        ): widget.onOpenFile,
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            widget.onPreviousPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): widget.onNextPage,
        SingleActivator(
          LogicalKeyboardKey.digit0,
          meta: useMeta,
          control: !useMeta,
        ): widget.onActualSize,
        SingleActivator(
          LogicalKeyboardKey.keyB,
          meta: useMeta,
          control: !useMeta,
        ): widget.onToggleSidebar,
        SingleActivator(
          LogicalKeyboardKey.equal,
          meta: useMeta,
          control: !useMeta,
        ): widget.onZoomIn,
        SingleActivator(
          LogicalKeyboardKey.equal,
          shift: true,
          meta: useMeta,
          control: !useMeta,
        ): widget.onZoomIn,
        SingleActivator(
          LogicalKeyboardKey.numpadAdd,
          meta: useMeta,
          control: !useMeta,
        ): widget.onZoomIn,
        SingleActivator(
          LogicalKeyboardKey.minus,
          meta: useMeta,
          control: !useMeta,
        ): widget.onZoomOut,
        SingleActivator(
          LogicalKeyboardKey.numpadSubtract,
          meta: useMeta,
          control: !useMeta,
        ): widget.onZoomOut,
      },
      child: Focus(
        focusNode: _readerFocusNode,
        autofocus: true,
        onKeyEvent: _handleFocusKeyEvent,
        child: widget.child,
      ),
    );
  }
}
