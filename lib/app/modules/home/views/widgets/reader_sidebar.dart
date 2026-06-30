import 'package:flutter/material.dart';

import '../../models/pdf_outline_entry.dart';
import '../../../../theme/app_colors.dart';

class ReaderSidebar extends StatelessWidget {
  const ReaderSidebar({
    super.key,
    required this.outline,
    required this.selectedOutlineId,
    required this.onOpenOutlinePage,
  });

  final List<PdfOutlineEntry> outline;
  final String? selectedOutlineId;
  final ValueChanged<PdfOutlineEntry> onOpenOutlinePage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        border: Border(
          right: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Text(
              'Contents',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: outline.isNotEmpty
                ? _OutlineList(
                    outline: outline,
                    selectedOutlineId: selectedOutlineId,
                    onOpenOutlinePage: onOpenOutlinePage,
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        '该文档没有目录结构。',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OutlineList extends StatelessWidget {
  const _OutlineList({
    required this.outline,
    required this.selectedOutlineId,
    required this.onOpenOutlinePage,
  });

  final List<PdfOutlineEntry> outline;
  final String? selectedOutlineId;
  final ValueChanged<PdfOutlineEntry> onOpenOutlinePage;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      itemCount: outline.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (BuildContext context, int index) {
        final PdfOutlineEntry item = outline[index];
        final bool selected = selectedOutlineId == item.id;
        return _SidebarListItem(
          selected: selected,
          padding: EdgeInsets.fromLTRB(14 + (item.depth * 14), 8, 8, 8),
          onTap: () => onOpenOutlinePage(item),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.textPrimary : AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.pageNumber}',
                style: TextStyle(
                  color: selected ? AppColors.textSecondary : AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarListItem extends StatelessWidget {
  const _SidebarListItem({
    required this.selected,
    required this.padding,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final EdgeInsetsGeometry padding;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.seed : AppColors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(AppColors.transparent),
        highlightColor: AppColors.transparent,
        splashColor: AppColors.transparent,
        hoverColor: AppColors.transparent,
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
