import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class AiSelectionModeBadge extends StatefulWidget {
  const AiSelectionModeBadge({super.key});

  @override
  State<AiSelectionModeBadge> createState() => _AiSelectionModeBadgeState();
}

class _AiSelectionModeBadgeState extends State<AiSelectionModeBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GoldFlowBorderPainter(
        animation: _controller,
        borderRadius: 999,
        borderWidth: 2,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(997),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF343434),
                  Color(0xFF171717),
                  Color(0xFF000000),
                ],
                stops: <double>[0, 0.48, 1],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'AI 选择模式',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldFlowBorderPainter extends CustomPainter {
  _GoldFlowBorderPainter({
    required this.animation,
    required this.borderRadius,
    required this.borderWidth,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final double borderRadius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final Rect borderRect = (Offset.zero & size).deflate(borderWidth / 2);
    final RRect borderRRect = RRect.fromRectAndRadius(
      borderRect,
      Radius.circular(borderRadius),
    );

    final SweepGradient goldFlow = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: const <Color>[
        Color(0xFF4A3510),
        Color(0xFF6E4F16),
        Color(0xFF8B661E),
        Color(0xFFD8A83A),
        Color(0xFFFFF1A8),
        Color(0xFFFFC84A),
        Color(0xFF8B661E),
        Color(0xFF6E4F16),
        Color(0xFF4A3510),
      ],
      stops: const <double>[0, 0.38, 0.58, 0.69, 0.735, 0.78, 0.87, 0.94, 1],
      transform: GradientRotation(animation.value * math.pi * 2),
    );
    final Shader shader = goldFlow.createShader(borderRect);

    canvas.drawRRect(
      borderRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 1.2
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawRRect(
      borderRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldFlowBorderPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth;
  }
}
