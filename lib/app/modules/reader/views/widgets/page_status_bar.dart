import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class PageStatusBar extends StatelessWidget {
  const PageStatusBar({
    super.key,
    required this.fileName,
    required this.currentPage,
    required this.pageCount,
    required this.zoom,
  });

  final String? fileName;
  final int currentPage;
  final int pageCount;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final String pageText =
        pageCount > 0 ? '$currentPage / $pageCount' : '-- / --';
    final String zoomText = '${(zoom * 100).round()}%';
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg.withValues(alpha: 0.88),
        border: const Border(
          top: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    fileName ?? '未打开文件',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Text(
            pageText,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 16),
          Text(
            zoomText,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
