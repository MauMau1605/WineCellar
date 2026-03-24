import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full-screen immersive background for the premium cave theme.
///
/// Draws dark walnut wood planks, a warm amber wash light from the top,
/// and a radial vignette. This widget is meant to be placed behind the
/// entire screen content via a [Stack].
class PremiumCaveScreenBackground extends StatelessWidget {
  const PremiumCaveScreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: CustomPaint(
        painter: _FullScreenBackgroundPainter(),
      ),
    );
  }
}

class _FullScreenBackgroundPainter extends CustomPainter {
  const _FullScreenBackgroundPainter();

  static const Color _warmAmber = Color(0xFFFFA500);
  static const Color _softGold = Color(0xFFFFCC33);
  static const Color _deepAmber = Color(0xFFD09830);

  @override
  void paint(Canvas canvas, Size size) {
    _drawDarkWoodPanels(canvas, size);
    _drawTopWashLight(canvas, size);
    _drawVignette(canvas, size);
  }

  // ── Dark wood panel wall (walnut / burnt oak) ─────────────────────────
  void _drawDarkWoodPanels(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Base fill – very dark warm brown
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF1E1610), Color(0xFF1A1208), Color(0xFF140E06)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Vertical planks
    final rng = math.Random(7);
    final plankCount = math.max(5, (w / 70).round());
    final plankW = w / plankCount;

    for (int i = 0; i < plankCount; i++) {
      final x = i * plankW;
      final v = rng.nextDouble();

      // Per-plank tint variation (warmer brown range)
      p.color = Color.fromRGBO(
        (40 + 25 * v).round(),
        (28 + 18 * v).round(),
        (14 + 12 * v).round(),
        1,
      );
      canvas.drawRect(Rect.fromLTWH(x + 1.2, 0, plankW - 2.4, h), p);

      // Grain lines
      for (int g = 0; g < 12; g++) {
        final gx = x + 3 + (g * (plankW - 6) / 12);
        final alpha = 0.03 + rng.nextDouble() * 0.06;
        p.color = Color.fromRGBO(
          60 + rng.nextInt(20),
          44 + rng.nextInt(14),
          26 + rng.nextInt(12),
          alpha,
        );
        p.style = PaintingStyle.stroke;
        p.strokeWidth = 0.4 + rng.nextDouble() * 0.9;
        final path = Path()..moveTo(gx, 0);
        double cx = gx;
        for (double y = 0; y < h; y += 25 + rng.nextDouble() * 20) {
          cx += (rng.nextDouble() - 0.5) * 1.8;
          path.lineTo(cx, y + 25);
        }
        canvas.drawPath(path, p);
      }
      p.style = PaintingStyle.fill;

      // Plank gap (dark seam)
      p.color = const Color(0xFF040200);
      canvas.drawRect(Rect.fromLTWH(x, 0, 1.2, h), p);
    }
    // Right edge gap
    p.color = const Color(0xFF040200);
    canvas.drawRect(Rect.fromLTWH(w - 1.2, 0, 1.2, h), p);

    // Subtle knots
    final knotRng = math.Random(321);
    for (int k = 0; k < 6; k++) {
      final kx = 40.0 + knotRng.nextDouble() * (w - 80);
      final ky = 80.0 + knotRng.nextDouble() * (h - 200).clamp(10, h);
      final kr = 3.0 + knotRng.nextDouble() * 5;
      p.shader = RadialGradient(
        colors: const [Color(0xFF0C0804), Color(0x000C0804)],
      ).createShader(Rect.fromCircle(center: Offset(kx, ky), radius: kr));
      canvas.drawCircle(Offset(kx, ky), kr, p);
      p.shader = null;
    }
  }

  // ── Top wash light (LED row at top of wall) ───────────────────────────
  void _drawTopWashLight(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Horizontal LED strip at top
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        _warmAmber.withValues(alpha: 0),
        _warmAmber.withValues(alpha: 0.4),
        _softGold.withValues(alpha: 0.5),
        _warmAmber.withValues(alpha: 0.4),
        _warmAmber.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, 3));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 3), p);
    p.shader = null;

    // Wash light beams pointing down
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _softGold.withValues(alpha: 0.12),
        _warmAmber.withValues(alpha: 0.06),
        _deepAmber.withValues(alpha: 0.02),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.15, 0.35, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h * 0.55));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.55), p);
    p.shader = null;

    // Concentrated center wash (brighter in the middle)
    p.shader = RadialGradient(
      center: const Alignment(0.0, -1.0),
      radius: 0.8,
      colors: [
        _softGold.withValues(alpha: 0.10),
        _warmAmber.withValues(alpha: 0.04),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h * 0.6));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.6), p);
    p.shader = null;
  }

  // ── Atmospheric vignette ──────────────────────────────────────────────
  void _drawVignette(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Radial vignette
    p.shader = RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: const [
        Color(0x00000000),
        Color(0x00000000),
        Color(0x40000000),
        Color(0x80000000),
      ],
      stops: const [0.0, 0.5, 0.8, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Edge darkening
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x70000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(0, 0, w, 45));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 45), p);

    p.shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: const [Color(0x70000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(0, h - 35, w, 35));
    canvas.drawRect(Rect.fromLTWH(0, h - 35, w, 35), p);

    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0x60000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(0, 0, 60, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, 60, h), p);

    p.shader = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: const [Color(0x60000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(w - 60, 0, 60, h));
    canvas.drawRect(Rect.fromLTWH(w - 60, 0, 60, h), p);

    p.shader = null;
  }

  @override
  bool shouldRepaint(covariant _FullScreenBackgroundPainter old) => false;
}
