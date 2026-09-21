import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../theme/app_theme.dart';

/// ── Motion layer (G2) ───────────────────────────────────────────────────────
/// Small, honest motion: numbers arrive, rings draw in, milestones celebrate.
/// Everything honors the OS "reduce motion" setting by rendering the final
/// state immediately.

/// Hero amounts count up instead of snapping (700 ms ease-out).
class CountUpText extends StatelessWidget {
  final Money amount;
  final TextStyle style;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.amount,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(amount.text, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: amount.minor.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Semantics(
        // Screen readers hear the final value once, not 60 mid-flight ones.
        label: amount.text,
        excludeSemantics: true,
        child: Text(
          Money(v.round(), amount.currency).text,
          style: style,
        ),
      ),
    );
  }
}

/// A one-second confetti burst over everything — goal reached, chore done.
/// Pure local overlay: no packages, no images, auto-removes itself.
void celebrate(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Confetti(onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  final VoidCallback onDone;

  const _Confetti({required this.onDone});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    final rng = math.Random(7);
    const colors = [kPrimary, kAccent, Color(0xFFFF6B6B), Color(0xFF7EC8F2)];
    _particles = List.generate(42, (i) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 2.2;
      final speed = 240 + rng.nextDouble() * 380;
      return _Particle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: colors[i % colors.length],
        size: 5 + rng.nextDouble() * 6,
        spin: (rng.nextDouble() - 0.5) * 12,
      );
    });
    _c.forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: MediaQuery.sizeOf(context),
        painter: _ConfettiPainter(
          t: _c.value,
          particles: _particles,
        ),
      ),
    );
  }
}

class _Particle {
  final double vx, vy, size, spin;
  final Color color;

  const _Particle({
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<_Particle> particles;

  _ConfettiPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint();
    for (final p in particles) {
      final time = t * 1.4;
      final x = origin.dx + p.vx * time;
      final y = origin.dy +
          p.vy * time +
          620 * time * time; // gravity
      if (y > size.height + 20) continue;
      paint.color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t * 3);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.55,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Pulsing placeholder bar for loading states (interface pass 3).
class Skeleton extends StatefulWidget {
  final double width;
  final double height;

  const Skeleton({super.key, this.width = 180, this.height = 14});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.track;
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, context.inkSoft, _c.value * 0.25),
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
      ),
    );
  }
}
