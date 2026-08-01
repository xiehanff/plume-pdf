import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 无系统边框的应用标题栏。
///
/// macOS 左侧预留 72px 给红绿灯按钮并设为可拖拽区域；
/// Windows/Linux 在右侧显示自定义窗口控制按钮。
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
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final Color foregroundColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return ColoredBox(
      color: backgroundColor,
      child: SizedBox(
        height: 50,
        child: Row(
          children: <Widget>[
            if (Platform.isMacOS)
              const SizedBox(
                width: 72,
                child: DragToMoveArea(child: SizedBox.expand()),
              ),
            Expanded(child: widget.child),
            if (!Platform.isMacOS)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _WindowButton(
                    tooltip: '最小化',
                    icon: Icons.minimize_rounded,
                    color: foregroundColor,
                    onPressed: windowManager.minimize,
                  ),
                  _WindowButton(
                    tooltip: _isMaximized ? '还原' : '最大化',
                    icon: _isMaximized
                        ? Icons.filter_none_rounded
                        : Icons.crop_square_rounded,
                    color: foregroundColor,
                    onPressed: () {
                      if (_isMaximized) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    },
                  ),
                  _WindowButton(
                    tooltip: '关闭',
                    icon: Icons.close_rounded,
                    color: foregroundColor,
                    isClose: true,
                    onPressed: windowManager.close,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
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
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 34,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          hoverColor: isClose
              ? Theme.of(context).colorScheme.error
              : color.withValues(alpha: 0.08),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
