import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Paints the premium wine cave decor (wood panels, cooler frame, glass door,
/// marble base, warm ambient glow) around a rectangular glass area.
///
/// The [glassRect] defines the area _inside_ the glass door where the
/// interactive bottle grid will be overlaid by a separate widget.
class PremiumCaveBackgroundPainter extends CustomPainter {
  /// Rectangle (in local widget coordinates) that represents the
  /// glass interior where the bottle grid lives.
  final Rect glassRect;

  PremiumCaveBackgroundPainter({required this.glassRect});

  // ── Derived layout ────────────────────────────────────────────────────
  static const double frameInsetX = 12.0;
  static const double frameInsetTop = 36.0;
  static const double frameInsetBottom = 22.0;
  static const double basePadX = 24.0;
  static const double baseHeight = 36.0;
  static const double baseGap = 6.0;

  // ── Warm amber palette (luxury lighting tones) ────────────────────────
  static const Color _warmAmber = Color(0xFFFFA500);
  static const Color _softGold = Color(0xFFFFCC33);
  static const Color _deepAmber = Color(0xFFD09830);

  Rect get _frameRect => Rect.fromLTRB(
        glassRect.left - frameInsetX,
        glassRect.top - frameInsetTop,
        glassRect.right + frameInsetX,
        glassRect.bottom + frameInsetBottom,
      );

  Rect get _baseRect => Rect.fromLTRB(
        _frameRect.left - basePadX,
        _frameRect.bottom + baseGap,
        _frameRect.right + basePadX,
        _frameRect.bottom + baseGap + baseHeight,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Wood wall, wash light & vignette are now drawn full-screen
    // by PremiumCaveScreenBackground. This painter only draws
    // the cooler unit and its immediate surroundings.
    _drawWallAmbientGlow(canvas, size);
    _drawCoolerDropShadow(canvas);
    _drawCoolerRecess(canvas);
    _drawCoolerBody(canvas, size);
    _drawControlPanel(canvas);
    _drawGlassDoorDecor(canvas);
    _drawHandle(canvas);
    _drawMarbleBase(canvas);
    _drawBaseLedStrip(canvas, size);
  }

  // ── Warm wall glow (around cooler) ────────────────────────────────────
  void _drawWallAmbientGlow(Canvas canvas, Size size) {
    final p = Paint();
    final fr = _frameRect;

    // Warm radial glow on wall behind and around cooler
    p.shader = RadialGradient(
      center: Alignment.center,
      radius: 0.75,
      colors: [
        _deepAmber.withValues(alpha: 0.08),
        _warmAmber.withValues(alpha: 0.04),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromLTRB(
      fr.left - 80, fr.top - 20,
      fr.right + 80, fr.bottom + 60,
    ));
    canvas.drawRect(Rect.fromLTRB(
      fr.left - 80, fr.top - 20,
      fr.right + 80, fr.bottom + 60,
    ), p);
    p.shader = null;
  }

  // ── Drop shadow behind cooler (3D depth) ──────────────────────────────
  void _drawCoolerDropShadow(Canvas canvas) {
    final p = Paint();
    final fr = _frameRect;

    // Soft large shadow for 3D wall depth
    p.shader = RadialGradient(
      center: Alignment.center,
      colors: const [Color(0x60000000), Color(0x30000000), Color(0x00000000)],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTRB(
      fr.left - 40, fr.top - 25, fr.right + 40, fr.bottom + 35,
    ));
    canvas.drawRect(Rect.fromLTRB(
      fr.left - 40, fr.top - 25, fr.right + 40, fr.bottom + 35,
    ), p);
    p.shader = null;
  }

  // ── Shadow recess ─────────────────────────────────────────────────────
  void _drawCoolerRecess(Canvas canvas) {
    final p = Paint();
    final fr = _frameRect;
    p.shader = RadialGradient(
      center: Alignment.center,
      colors: const [Color(0x50000000), Color(0x00000000)],
    ).createShader(Rect.fromLTRB(
      fr.left - 20, fr.top - 10, fr.right + 20, fr.bottom + 20,
    ));
    canvas.drawRect(Rect.fromLTRB(
      fr.left - 20, fr.top - 10, fr.right + 20, fr.bottom + 20,
    ), p);
    p.shader = null;
  }

  // ── Cooler body ───────────────────────────────────────────────────────
  void _drawCoolerBody(Canvas canvas, Size size) {
    final p = Paint();
    final fr = _frameRect;

    // Right side 3D depth
    p.color = const Color(0xFF121210);
    canvas.drawRect(Rect.fromLTWH(fr.right, fr.top + 4, 5, fr.height - 8), p);
    p.color = const Color(0xFF0A0A08);
    canvas.drawRect(
        Rect.fromLTWH(fr.right + 5, fr.top + 8, 2, fr.height - 14), p);

    // Main body – dark brushed steel
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0xFF1A1A18),
        Color(0xFF262624),
        Color(0xFF2E2E2C),
        Color(0xFF262624),
        Color(0xFF161614),
      ],
      stops: const [0.0, 0.12, 0.5, 0.88, 1.0],
    ).createShader(fr);
    canvas.drawRRect(
        RRect.fromRectAndRadius(fr, const Radius.circular(4)), p);
    p.shader = null;

    // Brushed metal micro-texture
    final rng = math.Random(42);
    for (double x = fr.left; x < fr.right; x += 2.5) {
      p.color = Color.fromRGBO(255, 255, 255, rng.nextDouble() * 0.007);
      canvas.drawRect(Rect.fromLTWH(x, fr.top, 0.5, fr.height), p);
    }

    // Top cap
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF363634), Color(0xFF1E1E1C)],
    ).createShader(Rect.fromLTWH(fr.left, fr.top, fr.width, 10));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(fr.left, fr.top, fr.width, 10),
          const Radius.circular(4)),
      p,
    );
    p.shader = null;

    // Door frame inset (dark border around glass)
    p.color = const Color(0xFF080806);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(
            glassRect.left - 3,
            glassRect.top - 3,
            glassRect.right + 3,
            glassRect.bottom + 3,
          ),
          const Radius.circular(3)),
      p,
    );

    // Bottom edge
    p.color = const Color(0xFF121210);
    canvas.drawRect(
        Rect.fromLTWH(fr.left + 5, fr.bottom - 3, fr.width - 10, 3), p);

    // Brand text
    final brand = TextPainter(
      text: const TextSpan(
        text: 'VINO RESERVE',
        style: TextStyle(
          fontSize: 6,
          color: Color(0x55908A80),
          letterSpacing: 2,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(minWidth: fr.width);
    brand.paint(canvas, Offset(fr.left, fr.bottom - 14));

    // Feet
    p.color = const Color(0xFF0C0C0A);
    for (final fx in [fr.left + 14.0, fr.right - 28.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(fx, fr.bottom, 14, 5), const Radius.circular(2)),
        p,
      );
    }
  }

  // ── Control panel ─────────────────────────────────────────────────────
  void _drawControlPanel(Canvas canvas) {
    final p = Paint();
    final fr = _frameRect;

    p.color = const Color(0xFF0E0E0C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(fr.left + 10, fr.top + 11, fr.width - 20, 16),
          const Radius.circular(3)),
      p,
    );

    // Temperature
    p.color = const Color(0xFF060C06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(fr.left + 14, fr.top + 13, 44, 12),
          const Radius.circular(2)),
      p,
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: '14°C',
        style: TextStyle(
          fontSize: 8,
          color: Color(0xFF38C038),
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(fr.left + 18, fr.top + 14));

    // Status dots
    for (int i = 0; i < 5; i++) {
      final dotX = fr.left + 68 + i * 9.0;
      final on = i < 3;
      p.color = on ? const Color(0xFF3888E0) : const Color(0xFF222220);
      canvas.drawCircle(Offset(dotX, fr.top + 19), 1.8, p);
      if (on) {
        p.color = const Color(0x283888E0);
        canvas.drawCircle(Offset(dotX, fr.top + 19), 3, p);
      }
    }
  }

  // ── Glass door decorations ────────────────────────────────────────────
  void _drawGlassDoorDecor(Canvas canvas) {
    final p = Paint();
    final gr = glassRect;

    // Dark tinted glass background
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0xFF030810),
        Color(0xFF061018),
        Color(0xFF08141E),
        Color(0xFF040A10),
      ],
      stops: const [0.0, 0.25, 0.65, 1.0],
    ).createShader(gr);
    canvas.drawRect(gr, p);
    p.shader = null;

    // Top LED strip (warm inside cooler)
    p.color = const Color(0xCCA8D0F0);
    canvas.drawRect(Rect.fromLTWH(gr.left, gr.top, gr.width, 3), p);

    // LED downward glow (cool interior lighting)
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0x2498C8F0), Color(0x0C70A0D0), Color(0x00000000)],
      stops: const [0.0, 0.35, 1.0],
    ).createShader(Rect.fromLTWH(gr.left, gr.top + 3, gr.width, 60));
    canvas.drawRect(Rect.fromLTWH(gr.left, gr.top + 3, gr.width, 60), p);
    p.shader = null;

    // Interior warm ambient (bottom-up)
    p.shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        _warmAmber.withValues(alpha: 0.08),
        _deepAmber.withValues(alpha: 0.04),
        _warmAmber.withValues(alpha: 0.02),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.18, 0.35, 1.0],
    ).createShader(gr);
    canvas.drawRect(gr, p);
    p.shader = null;

    // Glass reflections
    canvas.save();
    canvas.clipRect(gr);

    // Left edge faint reflection
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [Color(0x00FFFFFF), Color(0x0AFFFFFF), Color(0x00FFFFFF)],
    ).createShader(Rect.fromLTWH(gr.left, gr.top, 20, gr.height));
    canvas.drawRect(Rect.fromLTWH(gr.left, gr.top, 20, gr.height), p);
    p.shader = null;

    // Main diagonal reflection streak (glass brilliance)
    p.color = const Color(0x06FFFFFF);
    final refl = Path()
      ..moveTo(gr.left + gr.width * 0.18, gr.top)
      ..lineTo(gr.left + gr.width * 0.30, gr.top)
      ..lineTo(gr.left + gr.width * 0.04, gr.bottom)
      ..lineTo(gr.left - gr.width * 0.08, gr.bottom)
      ..close();
    canvas.drawPath(refl, p);

    // Second thinner reflection streak
    p.color = const Color(0x03FFFFFF);
    final refl2 = Path()
      ..moveTo(gr.left + gr.width * 0.38, gr.top)
      ..lineTo(gr.left + gr.width * 0.44, gr.top)
      ..lineTo(gr.left + gr.width * 0.20, gr.bottom)
      ..lineTo(gr.left + gr.width * 0.14, gr.bottom)
      ..close();
    canvas.drawPath(refl2, p);

    // Top-right corner highlight (glass sheen)
    p.shader = RadialGradient(
      center: const Alignment(0.8, -0.9),
      radius: 0.4,
      colors: const [Color(0x08FFFFFF), Color(0x00FFFFFF)],
    ).createShader(gr);
    canvas.drawRect(gr, p);
    p.shader = null;

    canvas.restore();

    // Glass border (subtle bright edge)
    p.color = const Color(0x16FFFFFF);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1;
    canvas.drawRect(gr.deflate(0.5), p);
    p.style = PaintingStyle.fill;
  }

  // ── Handle ────────────────────────────────────────────────────────────
  void _drawHandle(Canvas canvas) {
    final p = Paint();
    final fr = _frameRect;
    final hx = fr.left + 8.0;
    final hy = fr.top + fr.height / 2 - 32;

    // Chrome handle
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [Color(0xFF4A4A48), Color(0xFF6A6A68), Color(0xFF3C3C3A)],
    ).createShader(Rect.fromLTWH(hx, hy, 6, 64));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(hx, hy, 6, 64), const Radius.circular(3)),
      p,
    );
    p.shader = null;

    // Handle highlight
    p.color = const Color(0x18FFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(hx + 1.5, hy + 2, 2, 60), const Radius.circular(1)),
      p,
    );
  }

  // ── Black marble base (podium) ────────────────────────────────────────
  void _drawMarbleBase(Canvas canvas) {
    final p = Paint();
    final br = _baseRect;

    // Main marble body – dark stone gradient
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF282420),
        Color(0xFF1C1A16),
        Color(0xFF141210),
        Color(0xFF0E0C0A),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    ).createShader(br);
    canvas.drawRRect(
        RRect.fromRectAndRadius(br, const Radius.circular(3)), p);
    p.shader = null;

    // Top edge polished highlight
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        const Color(0x00FFFFFF),
        const Color(0x20FFFFFF),
        const Color(0x28FFFFFF),
        const Color(0x20FFFFFF),
        const Color(0x00FFFFFF),
      ],
      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
    ).createShader(Rect.fromLTWH(br.left + 3, br.top, br.width - 6, 1.5));
    canvas.drawRect(
        Rect.fromLTWH(br.left + 3, br.top, br.width - 6, 1.5), p);
    p.shader = null;

    // Marble veins (subtle diagonal streaks)
    final rng = math.Random(456);
    p.style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final sx = br.left + rng.nextDouble() * br.width;
      final sy = br.top + rng.nextDouble() * br.height;
      p.color = Color.fromRGBO(
        180 + rng.nextInt(40),
        170 + rng.nextInt(40),
        160 + rng.nextInt(30),
        0.02 + rng.nextDouble() * 0.03,
      );
      p.strokeWidth = 0.3 + rng.nextDouble() * 0.8;
      final path = Path()..moveTo(sx, sy);
      double cx = sx, cy = sy;
      for (int j = 0; j < 4; j++) {
        cx += 8 + rng.nextDouble() * 16;
        cy += (rng.nextDouble() - 0.5) * 4;
        path.lineTo(cx, cy);
      }
      canvas.drawPath(path, p);
    }
    p.style = PaintingStyle.fill;

    // Stone speckles
    for (int i = 0; i < 40; i++) {
      final sx = br.left + rng.nextDouble() * br.width;
      final sy = br.top + rng.nextDouble() * br.height;
      p.color = Color.fromRGBO(255, 255, 255, rng.nextDouble() * 0.015);
      canvas.drawRect(
          Rect.fromLTWH(sx, sy, 1 + rng.nextDouble() * 3, 0.5), p);
    }

    // Front face shadow (3D edge)
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0x00000000), Color(0x30000000)],
    ).createShader(
        Rect.fromLTWH(br.left, br.bottom - 6, br.width, 6));
    canvas.drawRect(
        Rect.fromLTWH(br.left, br.bottom - 6, br.width, 6), p);
    p.shader = null;
  }

  // ── LED strip under base + warm floor glow ────────────────────────────
  void _drawBaseLedStrip(Canvas canvas, Size size) {
    final p = Paint();
    final br = _baseRect;

    // LED strip (warm amber, visible under base edge)
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        _warmAmber.withValues(alpha: 0),
        _warmAmber.withValues(alpha: 0.9),
        _softGold.withValues(alpha: 1.0),
        _warmAmber.withValues(alpha: 0.9),
        _warmAmber.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.12, 0.5, 0.88, 1.0],
    ).createShader(
        Rect.fromLTWH(br.left + 6, br.bottom - 1, br.width - 12, 3));
    canvas.drawRect(
        Rect.fromLTWH(br.left + 6, br.bottom - 1, br.width - 12, 3), p);
    p.shader = null;

    // Close warm halo (floating effect)
    p.shader = RadialGradient(
      center: const Alignment(0, -0.5),
      radius: 1.0,
      colors: [
        _deepAmber.withValues(alpha: 0.25),
        _warmAmber.withValues(alpha: 0.12),
        _deepAmber.withValues(alpha: 0.04),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.25, 0.5, 1.0],
    ).createShader(
        Rect.fromLTWH(br.left - 40, br.bottom - 3, br.width + 80, 90));
    canvas.drawRect(
        Rect.fromLTWH(br.left - 40, br.bottom - 3, br.width + 80, 90), p);
    p.shader = null;

    // Floor warm reflection (amber pool of light)
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _warmAmber.withValues(alpha: 0.08),
        _deepAmber.withValues(alpha: 0.04),
        const Color(0x00000000),
      ],
    ).createShader(
        Rect.fromLTWH(br.left - 20, br.bottom + 6, br.width + 40, 70));
    canvas.drawRect(
        Rect.fromLTWH(br.left - 20, br.bottom + 6, br.width + 40, 70), p);
    p.shader = null;

    // Floor base reflection (subtle uplight on base bottom)
    p.shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        _warmAmber.withValues(alpha: 0.06),
        const Color(0x00000000),
      ],
    ).createShader(
        Rect.fromLTWH(br.left, br.bottom - 8, br.width, 8));
    canvas.drawRect(
        Rect.fromLTWH(br.left, br.bottom - 8, br.width, 8), p);
    p.shader = null;
  }

  @override
  bool shouldRepaint(covariant PremiumCaveBackgroundPainter old) =>
      old.glassRect != glassRect;
}
