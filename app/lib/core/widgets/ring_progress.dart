import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular progress ring used on goal cards (spec §7.5).
class RingProgress extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  const RingProgress({
    super.key,
    required this.value,
    this.size = 56,
    this.stroke = 7,
    required this.color,
    this.track = const Color(0xFFECEAE4),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0).toDouble();
    // G2: the ring draws in on first build and eases to new values.
    final painterValue = MediaQuery.disableAnimationsOf(context)
        ? target
        : null;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (painterValue != null)
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                value: painterValue,
                stroke: stroke,
                color: color,
                track: track,
              ),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: target),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  value: v,
                  stroke: stroke,
                  color: color,
                  track: track,
                ),
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color color;
  final Color track;

  _RingPainter({
    required this.value,
    required this.stroke,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}
