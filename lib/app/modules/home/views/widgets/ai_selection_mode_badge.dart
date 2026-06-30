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
      duration: const Duration(seconds: 3),
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
      painter: _RotatingGradientBorderPainter(
        animation: _controller,
        borderRadius: 999,
        borderWidth: 2,
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(997),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF301A4E),
              borderRadius: BorderRadius.circular(997),
            ),
            child: const Padding(
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

class _RotatingGradientBorderPainter extends CustomPainter {
  _RotatingGradientBorderPainter({
    required this.animation,
    required this.borderRadius,
    required this.borderWidth,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final double borderRadius;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Offset.zero & size;
    final outerRRect =
        RRect.fromRectAndRadius(outerRect, Radius.circular(borderRadius));

    final sweepGradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: const [
        Color(0xFFB39DDB),
        Color(0xFF7C4DFF),
        Color(0xFFE040FB),
        Color(0xFF536DFE),
        Color(0xFFB39DDB),
      ],
      transform: GradientRotation(animation.value * math.pi * 2),
    );

    canvas.drawRRect(
      outerRRect,
      Paint()..shader = sweepGradient.createShader(outerRect),
    );

    final innerRect = Rect.fromLTWH(
      borderWidth,
      borderWidth,
      size.width - borderWidth * 2,
      size.height - borderWidth * 2,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(borderRadius - borderWidth),
    );

    const bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3D2A5C), Color(0xFF2A1A3E)],
    );

    canvas.drawRRect(
      innerRRect,
      Paint()..shader = bgGradient.createShader(innerRect),
    );
  }

  @override
  bool shouldRepaint(covariant _RotatingGradientBorderPainter oldDelegate) =>
      true;
}
