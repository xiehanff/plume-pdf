import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:window_manager/window_manager.dart';

/// 跨 macOS/Linux/Windows 的应用标题栏。
///
/// macOS 左侧预留 72px 给红绿灯按钮并设为可拖拽区域；
/// Linux/Windows 在右侧显示自定义窗口控制按钮，并允许拖动标题栏。
class AppTitleBar extends StatefulWidget {
  const AppTitleBar({required this.child, super.key});

  final Widget child;

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _updateMaximizedState();
  }

  Future<void> _updateMaximizedState() async {
    final bool isMaximized = await windowManager.isMaximized();
    if (mounted && isMaximized != _isMaximized) {
      setState(() => _isMaximized = isMaximized);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final Color foregroundColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant;
    return ColoredBox(
      color: backgroundColor,
      child: SizedBox(
        height: 50,
        child: Row(
          children: <Widget>[
            // macOS keeps the native traffic-light buttons and reserves a
            // 72px draggable strip for them. The library's DragToMoveArea is
            // fine here because it contains no interactive widgets.
            if (Platform.isMacOS)
              const SizedBox(
                width: 72,
                child: DragToMoveArea(child: SizedBox.expand()),
              ),
            // Toolbar. On Linux/Windows it also serves as the window drag
            // region, but it must stay pan-only (see _DragToMoveArea) so the
            // many buttons inside it respond instantly.
            Expanded(
              child: Platform.isMacOS
                  ? widget.child
                  : _DragToMoveArea(child: widget.child),
            ),
            // Window controls are siblings of the drag region, never inside
            // it, so their taps are not delayed by a double-tap recognizer.
            if (!Platform.isMacOS)
              _WindowControls(
                isMaximized: _isMaximized,
                foregroundColor: foregroundColor,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _isMaximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _isMaximized = false);
    }
  }
}

/// A pan-only drag-to-move region.
///
/// window_manager's [DragToMoveArea] also registers an `onDoubleTap`
/// recognizer. A [DoubleTapGestureRecognizer] holds the gesture arena for
/// ~300ms after every single tap (see `GestureArenaManager.hold`), which makes
/// every button underneath it (IconButton, TextButton, PopupMenuButton, …)
/// feel laggy. This variant only handles window dragging, leaving taps on
/// descendant widgets to resolve immediately.
class _DragToMoveArea extends StatelessWidget {
  const _DragToMoveArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: child,
    );
  }
}

/// The minimize / maximize / close buttons.
///
/// Kept as a sibling of the drag region (not wrapped by it) so that clicking
/// them triggers immediately instead of being delayed by the drag area's
/// gesture recognizers.
class _WindowControls extends StatelessWidget {
  const _WindowControls({
    required this.isMaximized,
    required this.foregroundColor,
  });

  final bool isMaximized;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _WindowButton(
            tooltip: '最小化',
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedMinusSign,
              color: foregroundColor,
              size: 16,
              strokeWidth: 1.5,
            ),
            color: foregroundColor,
            onPressed: windowManager.minimize,
          ),
          _WindowButton(
            tooltip: isMaximized ? '还原' : '最大化',
            icon: Icon(
              isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              size: 16,
              color: foregroundColor,
            ),
            color: foregroundColor,
            onPressed: () {
              if (isMaximized) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
          ),
          _WindowButton(
            tooltip: '关闭',
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: foregroundColor,
            ),
            color: foregroundColor,
            isClose: true,
            onPressed: windowManager.close,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isClose = false,
  });

  final String tooltip;
  final Widget icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 50,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          hoverColor: isClose ? Colors.red : color.withValues(alpha: 0.08),
        ),
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}
