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

  /// 返回 true 表示 Reader 确实消费了本次 Escape。
  /// 普通阅读状态返回 false，让事件继续交给输入框、弹窗等后续控件。
  final bool Function() onEscape;
  final Widget child;

  @override
  State<ReaderShortcuts> createState() => _ReaderShortcutsState();
}

class _ReaderShortcutsState extends State<ReaderShortcuts> {
  final FocusNode _readerFocusNode = FocusNode(debugLabel: 'ReaderShortcuts');

  @override
  void initState() {
    super.initState();
    // pdfrx 自己持有 Viewer Focus。Linux 已验证 descendant Focus 可能在
    // 事件冒泡前消费 Escape，因此 Reader 只在 focus dispatch 的 early
    // 阶段处理 Escape；普通快捷键仍由 CallbackShortcuts 负责。
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyKeyEvent);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyKeyEvent);
    _readerFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleEarlyKeyEvent(KeyEvent event) {
    if (!_readerFocusNode.hasFocus ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    return widget.onEscape()
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
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
        child: widget.child,
      ),
    );
  }
}
