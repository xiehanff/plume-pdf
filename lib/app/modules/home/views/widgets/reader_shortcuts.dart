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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }
    final bool useMeta = usesMetaModifier();
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onEscape();
      return true;
    }
    if (_matchesModifierShortcut(event, useMeta, LogicalKeyboardKey.equal) ||
        _matchesModifierShortcut(event, useMeta, LogicalKeyboardKey.numpadAdd)) {
      widget.onZoomIn();
      return true;
    }
    if (_matchesModifierShortcut(event, useMeta, LogicalKeyboardKey.minus) ||
        _matchesModifierShortcut(
          event,
          useMeta,
          LogicalKeyboardKey.numpadSubtract,
        )) {
      widget.onZoomOut();
      return true;
    }
    return false;
  }

  bool _matchesModifierShortcut(
    KeyEvent event,
    bool useMeta,
    LogicalKeyboardKey key,
  ) {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool modifierPressed = useMeta
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
    return modifierPressed && event.logicalKey == key;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onEscape();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool useMeta = usesMetaModifier();
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): widget.onEscape,
          SingleActivator(
            LogicalKeyboardKey.keyO,
            meta: useMeta,
            control: !useMeta,
          ): widget.onOpenFile,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): widget.onPreviousPage,
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
        },
        child: widget.child,
      ),
    );
  }
}
