import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ── Data-viz primitives (G4) ────────────────────────────────────────────────
/// Hand-rolled, zero chart packages. Both honor the OS reduce-motion setting
/// by drawing the final state immediately.

/// Touch-scrub category donut. Tap a slice (or its legend row) to select it;
/// the selected slice lifts slightly and [center] shows the details.
class DonutChart extends StatelessWidget {
  /// (label, value, color) — values are relative shares.
  final List<(String, double, Color)> segments;
  final int selected;
  final ValueChanged<int> onTap;
  final double size;
  final double stroke;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.segments,
    required this.selected,
    required this.onTap,
    this.size = 168,
    this.stroke = 26,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (a, s) => a + s.$2);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        if (total <= 0) return;
        final c = Offset(size / 2, size / 2);
        final v = d.localPosition - c;
        var angle = math.atan2(v.dy, v.dx); // -π..π
        angle = (angle + math.pi / 2 + 2 * math.pi) % (2 * math.pi);
        var acc = 0.0;
        for (var i = 0; i < segments.length; i++) {
          final sweep = 2 * math.pi * segments[i].$2 / total;
          if (angle < acc + sweep || i == segments.length - 1) {
            onTap(i);
            return;
          }
          acc += sweep;
        }
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _DonutPainter(
                segments: segments,
                selected: selected,
                stroke: stroke,
              ),
            ),
            if (center != null) center!,
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(String, double, Color)> segments;
  final int selected;
  final double stroke;

  _DonutPainter({
    required this.segments,
    required this.selected,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (a, s) => a + s.$2);
    if (total <= 0) {
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFFECEAE4);
      canvas.drawCircle(size.center(Offset.zero),
          (size.width - stroke) / 2, track);
      return;
    }
    final radius = (size.width - stroke) / 2;
    var start = -math.pi / 2;
    for (var i = 0; i < segments.length; i++) {
      final sweep = 2 * math.pi * segments[i].$2 / total;
      final isSel = i == selected;
      final rect = Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: isSel ? radius + 3 : radius,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? stroke + 4 : stroke - 2
        ..strokeCap = StrokeCap.round
        ..color = segments[i].$3;
      canvas.drawArc(rect, start, math.max(sweep - 0.02, 0.01), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.selected != selected || old.segments != segments;
}

/// Six-month net trend: income minus expenses, one rounded bar per month,
/// tallest month highlighted. Values in a single currency (caller converts).
class TrendBars extends StatelessWidget {
  final List<(String, double)> bars; // (label, net)
  final double height;
  final Color positive;
  final Color negative;
  final Color track;
  final Color labelColor;

  const TrendBars({
    super.key,
    required this.bars,
    this.height = 96,
    required this.positive,
    required this.negative,
    required this.track,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxAbs = bars.fold<double>(
        1, (a, b) => math.max(a, b.$2.abs().toDouble()));
    final summary = 'Net trend: ' +
        bars.map((b) => '${b.$1} ${b.$2 >= 0 ? '+' : '-'}'
            '${b.$2.abs().round()}').join(', ');
    return Semantics(
      label: summary,
      child: ExcludeSemantics(
      child: SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (label, net) in bars) ...[
            Expanded(
              child: _Bar(
                fraction: (net.abs() / maxAbs).clamp(0.04, 1.0),
                positive: net >= 0,
                label: label,
                positiveColor: positive,
                negativeColor: negative,
                track: track,
                labelColor: labelColor,
              ),
            ),
          ],
        ],
      ),
      ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final bool positive;
  final String label;
  final Color positiveColor;
  final Color negativeColor;
  final Color track;
  final Color labelColor;

  const _Bar({
    required this.fraction,
    required this.positive,
    required this.label,
    required this.positiveColor,
    required this.negativeColor,
    required this.track,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = positive ? positiveColor : negativeColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: fraction,
                child: Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: labelColor)),
          ],
        ),
      ),
    );
  }
}
