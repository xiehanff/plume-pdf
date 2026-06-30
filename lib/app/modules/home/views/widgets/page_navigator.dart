import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../theme/app_colors.dart';

class PageNavigator extends StatelessWidget {
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

  double get _pageFieldWidth {
    final int digitCount = <int>[
      controller.text.trim().length,
      '$currentPage'.length,
      '$pageCount'.length,
      2,
    ].reduce((int a, int b) => a > b ? a : b);
    return (digitCount * 8.0 + 12).clamp(20.0, 44.0);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.pageNavBg),
        height: 30,
        width: 160,
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: onPreviousPage,
              tooltip: '上一页',
              style: IconButton.styleFrom(
                minimumSize: const Size(30, 30),
                maximumSize: const Size(30, 30),
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.textSecondary,
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                size: 16,
                strokeWidth: 1.5,
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
                        alignment: Alignment.center,
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
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${pageCount == 0 ? '--' : pageCount}',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: onNextPage,
              tooltip: '下一页',
              style: IconButton.styleFrom(
                minimumSize: const Size(30, 30),
                maximumSize: const Size(30, 30),
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.textSecondary,
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                strokeWidth: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
