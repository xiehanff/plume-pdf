import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../theme/app_colors.dart';

class PageNavigator extends StatelessWidget {
  static const TextStyle _pageTextStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
  );

  const PageNavigator({
    super.key,
    required this.controller,
    required this.currentPage,
    required this.pageCount,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final int currentPage;
  final int pageCount;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<String> onSubmitted;

  String get _pageCountLabel => pageCount == 0 ? '--' : '$pageCount';

  double get _pageFieldWidth {
    final int digitCount = <int>[
      controller.text.trim().length,
      '$currentPage'.length,
      '$pageCount'.length,
      2,
    ].reduce((int a, int b) => a > b ? a : b);
    return (digitCount * 8.0 + 24).clamp(48.0, 60.0);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.pageNavBg),
        height: 30,
        width: 176,
        child: Row(
          children: <Widget>[
            Tooltip(
              message: '上一页',
              child: InkWell(
                onTap: onPreviousPage,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    size: 16,
                    strokeWidth: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: _pageFieldWidth,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4545AD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Transform.translate(
                          offset: const Offset(0, -5),
                          transformHitTests: false,
                          child: Shortcuts(
                            shortcuts: const <ShortcutActivator, Intent>{
                              SingleActivator(LogicalKeyboardKey.arrowUp):
                                  DoNothingAndStopPropagationIntent(),
                              SingleActivator(LogicalKeyboardKey.arrowDown):
                                  DoNothingAndStopPropagationIntent(),
                            },
                            child: TextField(
                              controller: controller,
                              onSubmitted: onSubmitted,
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              textAlign: TextAlign.center,
                              textAlignVertical: TextAlignVertical.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: _pageTextStyle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('/', style: _pageTextStyle),
                    const SizedBox(width: 4),
                    Text(_pageCountLabel, style: _pageTextStyle),
                  ],
                ),
              ),
            ),
            Tooltip(
              message: '下一页',
              child: InkWell(
                onTap: onNextPage,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    strokeWidth: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
