import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Wraps the interactive cellar grid inside a stone-cave alcove visual.
///
/// Draws a recessed stone alcove with thick oak shelves between each row.
/// The [gridChild] is overlaid on top of the shelf area.
class StoneCaveWrapper extends StatelessWidget {
  final Widget gridChild;
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double rowNumWidth;
  final double rowGap;

  const StoneCaveWrapper({
    super.key,
    required this.gridChild,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.rowNumWidth,
    required this.rowGap,
  });

  // Layout constants
  static const double alcoveInsetX = 20.0;
  static const double alcoveInsetTop = 40.0;
  static const double alcoveInsetBottom = 24.0;
  static const double alcovePadX = 6.0;
  static const double alcovePadV = 8.0;

  @override
  Widget build(BuildContext context) {
    final gridWidth = rowNumWidth + columns * cellWidth;
    final gridHeight = rows * (cellHeight + rowGap);

    final alcoveWidth = gridWidth + alcovePadX * 2;
    final alcoveHeight = gridHeight + alcovePadV * 2;

    const ambientBleed = 50.0;
    final canvasWidth = alcoveWidth + alcoveInsetX * 2 + ambientBleed;
    final canvasHeight =
        alcoveHeight + alcoveInsetTop + alcoveInsetBottom + ambientBleed;

    final alcoveLeft = (canvasWidth - alcoveWidth) / 2;
    final alcoveTop = alcoveInsetTop + (ambientBleed / 4);

    final alcoveRect = Rect.fromLTWH(
      alcoveLeft,
      alcoveTop,
      alcoveWidth,
      alcoveHeight,
    );

    return SizedBox(
      width: canvasWidth,
      height: canvasHeight,
      child: Stack(
        children: [
          // Stone alcove background
          Positioned.fill(
            child: CustomPaint(
              painter: _StoneCaveAlcovePainter(alcoveRect: alcoveRect),
            ),
          ),
          // Oak shelf rails
          Positioned(
            left: alcoveRect.left + alcovePadX,
            top: alcoveRect.top + alcovePadV,
            width: gridWidth,
            height: gridHeight,
            child: CustomPaint(
              painter: _OakShelfPainter(
                rows: rows,
                cellHeight: cellHeight,
                rowGap: rowGap,
                rowNumWidth: rowNumWidth,
                gridWidth: gridWidth,
              ),
            ),
          ),
          // Interactive grid
          Positioned(
            left: alcoveRect.left + alcovePadX,
            top: alcoveRect.top + alcovePadV,
            width: gridWidth,
            height: gridHeight,
            child: gridChild,
          ),
        ],
      ),
    );
  }
}

/// Draws a recessed stone alcove with arch top, side pillars,
/// and warm ambient lighting inside.
class _StoneCaveAlcovePainter extends CustomPainter {
  final Rect alcoveRect;

  const _StoneCaveAlcovePainter({required this.alcoveRect});

  static const Color _warmFlame = Color(0xFFE8A030);
  static const Color _deepAmber = Color(0xFFD09020);

  @override
  void paint(Canvas canvas, Size size) {
    final ar = alcoveRect;
    final p = Paint();

    // ── Drop shadow behind alcove (depth effect) ──────────────────────
    p.shader = RadialGradient(
      center: Alignment.center,
      colors: const [Color(0x60000000), Color(0x30000000), Color(0x00000000)],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTRB(
      ar.left - 35, ar.top - 20, ar.right + 35, ar.bottom + 30,
    ));
    canvas.drawRect(
      Rect.fromLTRB(ar.left - 35, ar.top - 20, ar.right + 35, ar.bottom + 30),
      p,
    );
    p.shader = null;

    // ── Alcove arch path ──────────────────────────────────────────────
    final archPath = _alcovePath(ar);

    // Alcove dark interior
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF100C08),
        Color(0xFF161210),
        Color(0xFF1A1610),
      ],
    ).createShader(ar);
    canvas.drawPath(archPath, p);
    p.shader = null;

    // ── Stone blocks inside the alcove ────────────────────────────────
    canvas.save();
    canvas.clipPath(archPath);
    _drawInteriorStoneBlocks(canvas, ar);

    // ── Interior warm glow from above ────────────────────────────────
    p.shader = RadialGradient(
      center: const Alignment(0.0, -0.9),
      radius: 0.8,
      colors: [
        _warmFlame.withValues(alpha: 0.12),
        _deepAmber.withValues(alpha: 0.05),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.3, 1.0],
    ).createShader(ar);
    canvas.drawRect(ar, p);
    p.shader = null;

    // ── Side lighting strips (warm edge glow) ────────────────────────
    // Left side warm edge
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        _warmFlame.withValues(alpha: 0.06),
        const Color(0x00000000),
      ],
    ).createShader(Rect.fromLTWH(ar.left, ar.top, 20, ar.height));
    canvas.drawRect(Rect.fromLTWH(ar.left, ar.top, 20, ar.height), p);
    p.shader = null;
    // Right side warm edge
    p.shader = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        _warmFlame.withValues(alpha: 0.06),
        const Color(0x00000000),
      ],
    ).createShader(Rect.fromLTWH(ar.right - 20, ar.top, 20, ar.height));
    canvas.drawRect(Rect.fromLTWH(ar.right - 20, ar.top, 20, ar.height), p);
    p.shader = null;

    canvas.restore();

    // ── Arch border (stone moulding) ─────────────────────────────────
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 4.0;
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF4A3C2C),
        Color(0xFF3A2E20),
        Color(0xFF2E2418),
      ],
    ).createShader(ar);
    canvas.drawPath(archPath, p);
    p.style = PaintingStyle.fill;
    p.shader = null;

    // Inner border highlight
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 1.0;
    p.color = const Color(0x18FFFFFF);
    canvas.drawPath(archPath, p);
    p.style = PaintingStyle.fill;

    // ── Keystone decoration at arch apex ──────────────────────────────
    final cx = ar.center.dx;
    final keyTop = ar.top - 10;
    final keyPath = Path()
      ..moveTo(cx - 10, keyTop + 18)
      ..lineTo(cx - 7, keyTop)
      ..lineTo(cx + 7, keyTop)
      ..lineTo(cx + 10, keyTop + 18)
      ..close();
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF5A4830), Color(0xFF3E3020)],
    ).createShader(Rect.fromLTWH(cx - 10, keyTop, 20, 18));
    canvas.drawPath(keyPath, p);
    p.shader = null;

    // Keystone edge
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 0.8;
    p.color = const Color(0x20FFFFFF);
    canvas.drawPath(keyPath, p);
    p.style = PaintingStyle.fill;

    // ── Stone pillar side columns ────────────────────────────────────
    _drawPillar(canvas, Rect.fromLTWH(ar.left - 14, ar.top + 10, 14, ar.height - 10));
    _drawPillar(canvas, Rect.fromLTWH(ar.right, ar.top + 10, 14, ar.height - 10));

    // ── Base ledge ───────────────────────────────────────────────────
    final baseRect =
        Rect.fromLTWH(ar.left - 18, ar.bottom, ar.width + 36, 10);
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF4A3C2C), Color(0xFF2E2418)],
    ).createShader(baseRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(2)),
      p,
    );
    p.shader = null;
    // Base highlight
    p.color = const Color(0x15FFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(baseRect.left + 2, baseRect.top, baseRect.width - 4, 1.5),
      p,
    );
  }

  Path _alcovePath(Rect ar) {
    final path = Path();
    final archHeight = 24.0;
    path.moveTo(ar.left, ar.bottom);
    path.lineTo(ar.left, ar.top + archHeight);
    path.quadraticBezierTo(ar.center.dx, ar.top - archHeight, ar.right, ar.top + archHeight);
    path.lineTo(ar.right, ar.bottom);
    path.close();
    return path;
  }

  void _drawInteriorStoneBlocks(Canvas canvas, Rect ar) {
    final p = Paint();
    final rng = math.Random(77);
    double y = ar.top;
    int rowSeed = 0;
    while (y < ar.bottom) {
      final rowH = 16.0 + rng.nextDouble() * 12;
      final mortar = 1.0;
      double x = ar.left;
      if (rowSeed % 2 == 1) x -= 10 + rng.nextDouble() * 15;
      while (x < ar.right) {
        final bw = 30.0 + rng.nextDouble() * 35;
        final v = rng.nextDouble();
        p.color = Color.fromRGBO(
          (28 + 16 * v).round(),
          (22 + 12 * v).round(),
          (16 + 8 * v).round(),
          1,
        );
        canvas.drawRect(
          Rect.fromLTWH(x + mortar, y + mortar, bw - mortar * 2, rowH - mortar * 2),
          p,
        );
        p.color = const Color(0xFF080604);
        canvas.drawRect(Rect.fromLTWH(x + bw - mortar, y, mortar * 2, rowH), p);
        x += bw;
      }
      p.color = const Color(0xFF080604);
      canvas.drawRect(Rect.fromLTWH(ar.left, y + rowH - mortar, ar.width, mortar * 2), p);
      y += rowH;
      rowSeed++;
    }
  }

  void _drawPillar(Canvas canvas, Rect r) {
    final p = Paint();
    // Pillar body
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0xFF2E2418),
        Color(0xFF3E3020),
        Color(0xFF483824),
        Color(0xFF3E3020),
        Color(0xFF2E2418),
      ],
      stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
    ).createShader(r);
    canvas.drawRect(r, p);
    p.shader = null;

    // Pillar highlight
    p.color = const Color(0x10FFFFFF);
    canvas.drawRect(Rect.fromLTWH(r.left + r.width * 0.35, r.top, r.width * 0.3, r.height), p);

    // Vertical mortar lines (carved stone effect)
    final rng = math.Random(r.left.toInt());
    p.color = const Color(0x0C000000);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 0.5;
    for (double gy = r.top; gy < r.bottom; gy += 18 + rng.nextDouble() * 14) {
      canvas.drawLine(Offset(r.left + 2, gy), Offset(r.right - 2, gy), p);
    }
    p.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(covariant _StoneCaveAlcovePainter old) =>
      old.alcoveRect != alcoveRect;
}

/// Draws thick oak shelves between each row of the grid.
class _OakShelfPainter extends CustomPainter {
  final int rows;
  final double cellHeight;
  final double rowGap;
  final double rowNumWidth;
  final double gridWidth;

  const _OakShelfPainter({
    required this.rows,
    required this.cellHeight,
    required this.rowGap,
    required this.rowNumWidth,
    required this.gridWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final shelfHeight = math.max(rowGap * 0.92, 6.0);
    final railLeft = rowNumWidth + 2;
    final railWidth = gridWidth - rowNumWidth - 4;

    for (int r = 0; r < rows; r++) {
      final y = (r + 1) * (cellHeight + rowGap) - rowGap + 1;

      // Oak shelf gradient (warm natural oak)
      p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFB8863C),
          Color(0xFF9A6E2E),
          Color(0xFF7A5420),
          Color(0xFF6A4818),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(railLeft, y, railWidth, shelfHeight));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(railLeft, y, railWidth, shelfHeight),
          const Radius.circular(1.5),
        ),
        p,
      );
      p.shader = null;

      // Wood grain
      final rng = math.Random(y.toInt() + 200);
      p.color = const Color(0x18000000);
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 0.4;
      for (double gx = railLeft + 5;
          gx < railLeft + railWidth - 4;
          gx += 7 + rng.nextDouble() * 10) {
        canvas.drawLine(
          Offset(gx, y + 1),
          Offset(gx + 1 + rng.nextDouble() * 2, y + shelfHeight - 1),
          p,
        );
      }
      p.style = PaintingStyle.fill;

      // Top highlight (light hits the shelf edge)
      p.color = const Color(0x22FFFFFF);
      canvas.drawRect(
        Rect.fromLTWH(railLeft + 1, y, railWidth - 2, 1.5),
        p,
      );

      // Shelf bracket ends (small decorative notches)
      for (final bx in [railLeft, railLeft + railWidth - 6.0]) {
        p.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF6A4818), Color(0xFF4A3210)],
        ).createShader(Rect.fromLTWH(bx, y + shelfHeight, 6, 5));
        canvas.drawRect(Rect.fromLTWH(bx, y + shelfHeight, 6, 5), p);
        p.shader = null;
      }

      // Underside shadow from shelf
      p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x30000000), Color(0x00000000)],
      ).createShader(
        Rect.fromLTWH(railLeft, y + shelfHeight, railWidth, 4),
      );
      canvas.drawRect(
        Rect.fromLTWH(railLeft, y + shelfHeight, railWidth, 4),
        p,
      );
      p.shader = null;

      // Warm backlight glow above shelf (LED behind shelf)
      p.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFE8A030).withValues(alpha: 0.06),
          const Color(0x00000000),
        ],
      ).createShader(
        Rect.fromLTWH(railLeft, y - 12, railWidth, 12),
      );
      canvas.drawRect(
        Rect.fromLTWH(railLeft, y - 12, railWidth, 12),
        p,
      );
      p.shader = null;
    }
  }

  @override
  bool shouldRepaint(covariant _OakShelfPainter old) =>
      old.rows != rows ||
      old.cellHeight != cellHeight ||
      old.rowGap != rowGap ||
      old.gridWidth != gridWidth;
}
