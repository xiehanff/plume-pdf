import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../models/pdf_recent_file.dart';
import '../../../../theme/app_colors.dart';
import 'empty_reader_view.dart';

class RecentFilesGrid extends StatelessWidget {
  const RecentFilesGrid({
    super.key,
    required this.files,
    required this.unavailableFilePaths,
    required this.onOpenFile,
    required this.onRecentFileTap,
    required this.onDeleteRecentFile,
    required this.onRecoverRecentFile,
    this.onOpenWifiTransfer,
  });

  final List<PdfRecentFile> files;
  final Set<String> unavailableFilePaths;
  final VoidCallback onOpenFile;
  final ValueChanged<String> onRecentFileTap;
  final ValueChanged<String> onDeleteRecentFile;
  final ValueChanged<String> onRecoverRecentFile;
  final VoidCallback? onOpenWifiTransfer;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return EmptyReaderView(
        onOpenFile: onOpenFile,
        onOpenWifiTransfer: onOpenWifiTransfer,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: <Widget>[
                const Text(
                  '最近阅读',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onOpenWifiTransfer != null) ...<Widget>[
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onOpenWifiTransfer,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedWifi01,
                      size: 17,
                      strokeWidth: 1.5,
                    ),
                    label: const Text('WiFi 传书'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, BoxConstraints constraints) {
                const double itemWidth = 180;
                final int crossAxisCount = (constraints.maxWidth / itemWidth)
                    .floor()
                    .clamp(1, 6);
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: files.length,
                  itemBuilder: (_, int index) {
                    final PdfRecentFile file = files[index];
                    return _GridItem(
                      file: file,
                      unavailable: unavailableFilePaths.contains(file.path),
                      onTap: () => onRecentFileTap(file.path),
                      onDelete: () => onDeleteRecentFile(file.path),
                      onRecover: () => onRecoverRecentFile(file.path),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  static const double _kCardRadius = 16;
  static const double _kActionButtonSize = 30;
  static const double _kTopInset = 12;
  static const double _kBadgeHeight = 24;

  const _GridItem({
    required this.file,
    required this.unavailable,
    required this.onTap,
    required this.onDelete,
    required this.onRecover,
  });

  final PdfRecentFile file;
  final bool unavailable;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: unavailable ? null : onTap,
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kCardRadius),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                file.coverPath != null && file.coverPath!.isNotEmpty
                    ? Image.file(
                        File(file.coverPath!),
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(file),
                      )
                    : _buildPlaceholder(file),
                if (unavailable)
                  Positioned(
                    left: 12,
                    right: 10,
                    top: _kTopInset,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        const _UnavailableBadge(),
                        const Spacer(),
                        _UnavailableMenuButton(
                          onDelete: onDelete,
                          onRecover: onRecover,
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _InfoFooter(file: file, onDelete: onDelete),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${twoDigits(time.month)}-${twoDigits(time.day)} '
        '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  static Widget _buildPlaceholder(PdfRecentFile file) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3D2A5C), Color(0xFF2A1A3E)],
        ),
      ),
      child: Center(
        child: Text(
          file.name.isNotEmpty ? file.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 48,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}

class _InfoFooter extends StatelessWidget {
  const _InfoFooter({required this.file, required this.onDelete});

  final PdfRecentFile file;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: const BoxDecoration(
        color: Color(0xF0000000),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_GridItem._kCardRadius),
          bottomRight: Radius.circular(_GridItem._kCardRadius),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '添加于 ${_GridItem._formatTime(file.lastOpenedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionCircleButton(
            tooltip: '删除记录',
            icon: Icons.delete_outline,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _UnavailableMenuButton extends StatelessWidget {
  const _UnavailableMenuButton({
    required this.onDelete,
    required this.onRecover,
  });

  final VoidCallback onDelete;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: SizedBox(
        width: _GridItem._kActionButtonSize,
        height: _GridItem._kActionButtonSize,
        child: PopupMenuButton<_UnavailableAction>(
          tooltip: '无效记录操作',
          onSelected: (_UnavailableAction action) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              switch (action) {
                case _UnavailableAction.delete:
                  onDelete();
                case _UnavailableAction.recover:
                  onRecover();
              }
            });
          },
          itemBuilder: (_) => const <PopupMenuEntry<_UnavailableAction>>[
            PopupMenuItem<_UnavailableAction>(
              value: _UnavailableAction.delete,
              child: Text('删除记录'),
            ),
            PopupMenuItem<_UnavailableAction>(
              value: _UnavailableAction.recover,
              child: Text('重新打开'),
            ),
          ],
          color: const Color(0xE61F2127),
          padding: EdgeInsets.zero,
          icon: Container(
            width: _GridItem._kActionButtonSize,
            height: _GridItem._kActionButtonSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xD9000000),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.more_horiz, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  const _ActionCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _GridItem._kActionButtonSize,
      height: _GridItem._kActionButtonSize,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xD9000000),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: 16),
      ),
    );
  }
}

class _UnavailableBadge extends StatelessWidget {
  const _UnavailableBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      constraints: const BoxConstraints(minHeight: _GridItem._kBadgeHeight),
      decoration: BoxDecoration(
        color: const Color(0xFFD93A32),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Center(
        child: Text(
          '无法访问',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

enum _UnavailableAction { delete, recover }
