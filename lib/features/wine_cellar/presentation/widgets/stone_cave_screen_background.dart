import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full-screen immersive background for the stone cave theme.
///
/// Draws a limestone wall, an arched alcove silhouette at the top,
/// warm torch-like lighting falling from above, and an atmospheric
/// vignette. Place behind all screen content via a [Stack].
class StoneCaveScreenBackground extends StatelessWidget {
  const StoneCaveScreenBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: CustomPaint(
        painter: _StoneCaveBackgroundPainter(),
      ),
    );
  }
}

class _StoneCaveBackgroundPainter extends CustomPainter {
  const _StoneCaveBackgroundPainter();

  static const Color _warmFlame = Color(0xFFE8A030);
  static const Color _deepAmber = Color(0xFFD09020);

  @override
  void paint(Canvas canvas, Size size) {
    _drawStoneWall(canvas, size);
    _drawArch(canvas, size);
    _drawTorchLight(canvas, size);
    _drawVignette(canvas, size);
  }

  // ── Stone wall texture ────────────────────────────────────────────────
  void _drawStoneWall(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Base fill – very dark warm grey-brown
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF1E1A14), Color(0xFF181410), Color(0xFF14100C)],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Draw stone blocks (irregular rows)
    final rng = math.Random(42);
    double y = 0;
    int rowSeed = 0;
    while (y < h) {
      final rowHeight = 22.0 + rng.nextDouble() * 18;
      final mortarY = 1.2 + rng.nextDouble() * 0.6;
      double x = 0;
      // Offset every other row for a brick-like pattern
      if (rowSeed % 2 == 1) {
        x = -15 - rng.nextDouble() * 30;
      }
      while (x < w) {
        final blockWidth = 40.0 + rng.nextDouble() * 50;

        // Per-block colour variation (warm sandstone range)
        final v = rng.nextDouble();
        p.color = Color.fromRGBO(
          (34 + 18 * v).round(),
          (28 + 14 * v).round(),
          (20 + 10 * v).round(),
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

        // Surface roughness – tiny speckles
        for (int s = 0; s < 4; s++) {
          final sx = x + mortarY + rng.nextDouble() * (blockWidth - mortarY * 4);
          final sy = y + mortarY + rng.nextDouble() * (rowHeight - mortarY * 4);
          p.color = Color.fromRGBO(
            60 + rng.nextInt(30),
            50 + rng.nextInt(20),
            38 + rng.nextInt(15),
            0.08 + rng.nextDouble() * 0.06,
          );
          canvas.drawCircle(Offset(sx, sy), 0.6 + rng.nextDouble() * 1.2, p);
        }

        // Mortar line (dark seam)
        p.color = const Color(0xFF0A0806);
        canvas.drawRect(Rect.fromLTWH(x + blockWidth - mortarY, y, mortarY * 2, rowHeight), p);

        x += blockWidth;
      }
      // Horizontal mortar
      p.color = const Color(0xFF0A0806);
      canvas.drawRect(Rect.fromLTWH(0, y + rowHeight - mortarY, w, mortarY * 2), p);

      y += rowHeight;
      rowSeed++;
    }

    // Subtle moss / age stains
    final stainRng = math.Random(99);
    for (int k = 0; k < 8; k++) {
      final kx = stainRng.nextDouble() * w;
      final ky = stainRng.nextDouble() * h;
      final kr = 15.0 + stainRng.nextDouble() * 30;
      p.shader = RadialGradient(
        colors: [
          Color.fromRGBO(20, 30, 15, 0.06 + stainRng.nextDouble() * 0.04),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromCircle(center: Offset(kx, ky), radius: kr));
      canvas.drawCircle(Offset(kx, ky), kr, p);
      p.shader = null;
    }
  }

  // ── Arched ceiling silhouette ─────────────────────────────────────────
  void _drawArch(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Semi-transparent dark arch overlay at top
    final archPath = Path();
    final archHeight = h * 0.18;
    final archWidth = w * 0.8;
    final cx = w / 2;

    // Draw a wide barrel-vault arch shape
    archPath.moveTo(0, 0);
    archPath.lineTo(0, archHeight * 0.6);
    archPath.quadraticBezierTo(cx, -archHeight * 0.5, w, archHeight * 0.6);
    archPath.lineTo(w, 0);
    archPath.close();

    // Dark ceiling fill
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF0C0A06), Color(0xFF141008)],
    ).createShader(Rect.fromLTWH(0, 0, w, archHeight));
    canvas.drawPath(archPath, p);
    p.shader = null;

    // Arch edge highlight (keystone glow)
    final archEdge = Path();
    archEdge.moveTo(cx - archWidth / 2, archHeight * 0.6);
    archEdge.quadraticBezierTo(cx, -archHeight * 0.3, cx + archWidth / 2, archHeight * 0.6);

    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2.5;
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        const Color(0x00000000),
        _warmFlame.withValues(alpha: 0.10),
        _warmFlame.withValues(alpha: 0.18),
        _warmFlame.withValues(alpha: 0.10),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, archHeight));
    canvas.drawPath(archEdge, p);
    p.style = PaintingStyle.fill;
    p.shader = null;
  }

  // ── Warm torch / overhead lighting ────────────────────────────────────
  void _drawTorchLight(Canvas canvas, Size size) {
    final p = Paint();
    final w = size.width, h = size.height;

    // Central warm glow from top (as if a torch or lantern hangs)
    p.shader = RadialGradient(
      center: const Alignment(0.0, -0.85),
      radius: 0.9,
      colors: [
        _warmFlame.withValues(alpha: 0.10),
        _deepAmber.withValues(alpha: 0.05),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.35, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h * 0.7));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.7), p);
    p.shader = null;

    // Downward wash from arch apex
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _warmFlame.withValues(alpha: 0.08),
        _deepAmber.withValues(alpha: 0.04),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.25, 1.0],
    ).createShader(Rect.fromLTWH(w * 0.2, 0, w * 0.6, h * 0.5));
    canvas.drawRect(Rect.fromLTWH(w * 0.2, 0, w * 0.6, h * 0.5), p);
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
        Color(0x50000000),
        Color(0x90000000),
      ],
      stops: const [0.0, 0.45, 0.78, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
    p.shader = null;

    // Edge darkening
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x80000000), Color(0x00000000)],
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
  bool shouldRepaint(covariant _StoneCaveBackgroundPainter old) => false;
}
