import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'reader_shortcut_platform.dart';

class ReaderShortcuts extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool useMeta = usesMetaModifier();
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        SingleActivator(
          LogicalKeyboardKey.keyO,
          meta: useMeta,
          control: !useMeta,
        ): onOpenFile,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): onPreviousPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): onNextPage,
        SingleActivator(
          LogicalKeyboardKey.digit0,
          meta: useMeta,
          control: !useMeta,
        ): onActualSize,
        SingleActivator(
          LogicalKeyboardKey.keyB,
          meta: useMeta,
          control: !useMeta,
        ): onToggleSidebar,
        SingleActivator(
          LogicalKeyboardKey.equal,
          meta: useMeta,
          control: !useMeta,
        ): onZoomIn,
        SingleActivator(
          LogicalKeyboardKey.equal,
          shift: true,
          meta: useMeta,
          control: !useMeta,
        ): onZoomIn,
        SingleActivator(
          LogicalKeyboardKey.numpadAdd,
          meta: useMeta,
          control: !useMeta,
        ): onZoomIn,
        SingleActivator(
          LogicalKeyboardKey.minus,
          meta: useMeta,
          control: !useMeta,
        ): onZoomOut,
        SingleActivator(
          LogicalKeyboardKey.numpadSubtract,
          meta: useMeta,
          control: !useMeta,
        ): onZoomOut,
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, KeyEvent event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            onEscape();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }
}
