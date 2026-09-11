import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Premium circular gradient loading indicator with a rotating arc,
/// soft lavender track, rounded caps, and clean "Loading..." typography.
class CircularGradientSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color trackColor;
  final List<Color> gradientColors;
  final double arcAngle;
  final String? label;
  final TextStyle? labelStyle;
  final double spacing;
  final Duration rotationDuration;

  const CircularGradientSpinner({
    super.key,
    this.size = 46.0,
    this.strokeWidth = 3.8,
    this.trackColor = const Color(0xFFEDE9FE),
    this.gradientColors = const [
      Color(0x00664DFF),
      Color(0x66664DFF),
      Color(0xFF664DFF),
      AppColors.primary,
    ],
    this.arcAngle = math.pi * 0.65, // ~117 degrees
    this.label = 'Loading...',
    this.labelStyle,
    this.spacing = 16.0,
    this.rotationDuration = const Duration(milliseconds: 950),
  });

  @override
  State<CircularGradientSpinner> createState() =>
      _CircularGradientSpinnerState();
}

class _CircularGradientSpinnerState extends State<CircularGradientSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.rotationDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabelStyle = widget.labelStyle ??
        const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF7E849E),
          letterSpacing: 0.2,
        );

    final spinner = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _CircularGradientPainter(
              animationValue: _controller.value,
              trackColor: widget.trackColor,
              gradientColors: widget.gradientColors,
              strokeWidth: widget.strokeWidth,
              arcAngle: widget.arcAngle,
            ),
          );
        },
      ),
    );

    if (widget.label == null || widget.label!.isEmpty) {
      return spinner;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        spinner,
        SizedBox(height: widget.spacing),
        Text(
          widget.label!,
          style: effectiveLabelStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _CircularGradientPainter extends CustomPainter {
  final double animationValue; // 0.0 .. 1.0
  final Color trackColor;
  final List<Color> gradientColors;
  final double strokeWidth;
  final double arcAngle;

  const _CircularGradientPainter({
    required this.animationValue,
    required this.trackColor,
    required this.gradientColors,
    required this.strokeWidth,
    required this.arcAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Draw full circular background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw rotating gradient arc with rounded ends using hardware canvas rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animationValue * 2 * math.pi);

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: arcAngle,
      colors: gradientColors,
    );

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      0.0,
      arcAngle,
      false,
      arcPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CircularGradientPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.arcAngle != arcAngle;
  }
}
