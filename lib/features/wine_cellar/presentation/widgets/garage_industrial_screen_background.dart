import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full-screen immersive background for the garage industrial theme.
///
/// Draws a cinder-block wall, a harsh neon ceiling light, and an
/// atmospheric cold vignette. Place behind all screen content via a [Stack].
class GarageIndustrialScreenBackground extends StatelessWidget {
  const GarageIndustrialScreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: CustomPaint(
        painter: _GarageBackgroundPainter(),
      ),
    );
  }
}

class _GarageBackgroundPainter extends CustomPainter {
  const _GarageBackgroundPainter();

  static const Color _neonWhite = Color(0xFFD0D8E8);
  static const Color _coldBlue = Color(0xFF8AC4E8);

  @override
  void paint(Canvas canvas, Size size) {
    _drawCinderBlockWall(canvas, size);
    _drawCeilingStructure(canvas, size);
    _drawNeonLight(canvas, size);
    _drawVignette(canvas, size);
  }

  // ── Cinder-block wall texture ─────────────────────────────────────
  void _drawCinderBlockWall(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Base fill – very dark cold grey
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1C1C22), Color(0xFF18181E), Color(0xFF141418)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Draw concrete blocks (regular rows, industrial regularity)
    final rng = math.Random(31);
    double y = 0;
    int rowSeed = 0;
    while (y < h) {
      final rowHeight = 24.0 + rng.nextDouble() * 10;
      final mortarY = 1.5 + rng.nextDouble() * 0.5;
      double x = 0;
      // Offset every other row (stretcher bond)
      if (rowSeed % 2 == 1) {
        x = -20 - rng.nextDouble() * 25;
      }
      while (x < w) {
        final blockWidth = 50.0 + rng.nextDouble() * 40;

        // Per-block colour variation (cold grey range)
        final v = rng.nextDouble();
        p.color = Color.fromRGBO(
          (32 + 14 * v).round(),
          (32 + 14 * v).round(),
          (36 + 16 * v).round(),
          1,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            x + mortarY,
            y + mortarY,
            blockWidth - mortarY * 2,
            rowHeight - mortarY * 2,
          ),
          p,
        );

        // Surface porosity – tiny speckles
        for (int s = 0; s < 5; s++) {
          final sx =
              x + mortarY + rng.nextDouble() * (blockWidth - mortarY * 4);
          final sy =
              y + mortarY + rng.nextDouble() * (rowHeight - mortarY * 4);
          p.color = Color.fromRGBO(
            50 + rng.nextInt(25),
            50 + rng.nextInt(25),
            54 + rng.nextInt(25),
            0.06 + rng.nextDouble() * 0.06,
          );
          canvas.drawCircle(Offset(sx, sy), 0.5 + rng.nextDouble() * 1.0, p);
        }

        // Mortar line (dark seam)
        p.color = const Color(0xFF0C0C10);
        canvas.drawRect(
          Rect.fromLTWH(x + blockWidth - mortarY, y, mortarY * 2, rowHeight),
          p,
        );

        x += blockWidth;
      }
      // Horizontal mortar
      p.color = const Color(0xFF0C0C10);
      canvas.drawRect(
        Rect.fromLTWH(0, y + rowHeight - mortarY, w, mortarY * 2),
        p,
      );

      y += rowHeight;
      rowSeed++;
    }

    // Cement stains / efflorescence patches
    final stainRng = math.Random(73);
    for (int k = 0; k < 10; k++) {
      final kx = stainRng.nextDouble() * w;
      final ky = stainRng.nextDouble() * h;
      final kr = 12.0 + stainRng.nextDouble() * 25;
      p.shader = RadialGradient(
        colors: [
          Color.fromRGBO(
            180 + stainRng.nextInt(40),
            180 + stainRng.nextInt(40),
            185 + stainRng.nextInt(40),
            0.03 + stainRng.nextDouble() * 0.03,
          ),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromCircle(center: Offset(kx, ky), radius: kr));
      canvas.drawCircle(Offset(kx, ky), kr, p);
      p.shader = null;
    }
  }

  // ── Ceiling structure (industrial beam) ───────────────────────────
  void _drawCeilingStructure(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width;

    // Dark ceiling band at very top
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF0E0E12), Color(0xFF16161C)],
    ).createShader(Rect.fromLTWH(0, 0, w, 30));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 30), p);
    p.shader = null;

    // Steel beam across the top
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF3A3A42),
        Color(0xFF2E2E36),
        Color(0xFF22222A),
      ],
    ).createShader(Rect.fromLTWH(0, 26, w, 8));
    canvas.drawRect(Rect.fromLTWH(0, 26, w, 8), p);
    p.shader = null;

    // Beam bottom edge highlight
    p.color = const Color(0x18FFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 33, w, 1), p);
  }

  // ── Neon tube light ───────────────────────────────────────────────
  void _drawNeonLight(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Central cold glow from top (neon tube)
    p.shader = RadialGradient(
      center: const Alignment(0.0, -0.92),
      radius: 0.85,
      colors: [
        _neonWhite.withValues(alpha: 0.12),
        _coldBlue.withValues(alpha: 0.06),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.3, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h * 0.65));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.65), p);
    p.shader = null;

    // Neon tube strip (thin bright line)
    final tubeLeft = w * 0.2;
    final tubeRight = w * 0.8;
    final tubeY = 20.0;

    // Glow halo around tube
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _coldBlue.withValues(alpha: 0.04),
        _neonWhite.withValues(alpha: 0.10),
        _coldBlue.withValues(alpha: 0.04),
      ],
    ).createShader(Rect.fromLTWH(tubeLeft, tubeY - 8, tubeRight - tubeLeft, 16));
    canvas.drawRect(
      Rect.fromLTWH(tubeLeft, tubeY - 8, tubeRight - tubeLeft, 16),
      p,
    );
    p.shader = null;

    // Bright tube core
    p.color = _neonWhite.withValues(alpha: 0.30);
    canvas.drawRect(
      Rect.fromLTWH(tubeLeft, tubeY - 1, tubeRight - tubeLeft, 2.5),
      p,
    );

    // Downward wash
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _neonWhite.withValues(alpha: 0.06),
        _coldBlue.withValues(alpha: 0.03),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.2, 1.0],
    ).createShader(Rect.fromLTWH(w * 0.15, 30, w * 0.7, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(w * 0.15, 30, w * 0.7, h * 0.45), p);
    p.shader = null;
  }

  // ── Cold atmospheric vignette ─────────────────────────────────────
  void _drawVignette(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Radial vignette
    p.shader = const RadialGradient(
      center: Alignment.center,
      radius: 0.85,
      colors: [
        Color(0x00000000),
        Color(0x00000000),
        Color(0x50000000),
        Color(0x90000000),
      ],
      stops: [0.0, 0.45, 0.78, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Edge darkening
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x90000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(0, 0, w, 50));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 50), p);

    p.shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: const [Color(0x70000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(0, h - 40, w, 40));
    canvas.drawRect(Rect.fromLTWH(0, h - 40, w, 40), p);

    p.shader = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0x70000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(0, 0, 65, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, 65, h), p);

    p.shader = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: const [Color(0x70000000), Color(0x00000000)],
    ).createShader(Rect.fromLTWH(w - 65, 0, 65, h));
    canvas.drawRect(Rect.fromLTWH(w - 65, 0, 65, h), p);
    p.shader = null;
  }

  @override
  bool shouldRepaint(covariant _GarageBackgroundPainter old) => false;
}
