import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Wraps the interactive cellar grid inside a garage industrial rack visual.
///
/// Draws a recessed steel frame with perforated uprights and galvanised
/// metal shelves between each row. The [gridChild] is overlaid on top.
class GarageIndustrialWrapper extends StatelessWidget {
  final Widget gridChild;
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double rowNumWidth;
  final double rowGap;

  const GarageIndustrialWrapper({
    super.key,
    required this.gridChild,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.rowNumWidth,
    required this.rowGap,
  });

  // Layout constants (matching StoneCaveWrapper pattern)
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
          // Steel frame background
          Positioned.fill(
            child: CustomPaint(
              painter: _GarageFramePainter(alcoveRect: alcoveRect),
            ),
          ),
          // Metal shelves
          Positioned(
            left: alcoveRect.left + alcovePadX,
            top: alcoveRect.top + alcovePadV,
            width: gridWidth,
            height: gridHeight,
            child: CustomPaint(
              painter: _SteelShelfPainter(
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

/// Draws a bolted steel rack frame with perforated upright columns.
class _GarageFramePainter extends CustomPainter {
  final Rect alcoveRect;

  const _GarageFramePainter({required this.alcoveRect});

  static const Color _coldBlue = Color(0xFF8AC4E8);

  @override
  void paint(Canvas canvas, Size size) {
    final ar = alcoveRect;
    final p = Paint();

    // ── Drop shadow behind frame ─────────────────────────────────────
    p.shader = RadialGradient(
      center: Alignment.center,
      colors: const [Color(0x50000000), Color(0x20000000), Color(0x00000000)],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTRB(
      ar.left - 30, ar.top - 15, ar.right + 30, ar.bottom + 25,
    ));
    canvas.drawRect(
      Rect.fromLTRB(ar.left - 30, ar.top - 15, ar.right + 30, ar.bottom + 25),
      p,
    );
    p.shader = null;

    // ── Flat industrial frame (no arch — rectangular) ────────────────
    final framePath = Path()
      ..addRect(ar);

    // Frame dark interior
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF141418),
        Color(0xFF18181E),
        Color(0xFF1C1C22),
      ],
    ).createShader(ar);
    canvas.drawPath(framePath, p);
    p.shader = null;

    // ── Interior cinder-block texture ────────────────────────────────
    canvas.save();
    canvas.clipRect(ar);
    _drawInteriorBlocks(canvas, ar);

    // ── Cold blue LED glow from top ──────────────────────────────────
    p.shader = RadialGradient(
      center: const Alignment(0.0, -0.95),
      radius: 0.7,
      colors: [
        _coldBlue.withValues(alpha: 0.08),
        _coldBlue.withValues(alpha: 0.03),
        const Color(0x00000000),
      ],
      stops: const [0.0, 0.3, 1.0],
    ).createShader(ar);
    canvas.drawRect(ar, p);
    p.shader = null;

    canvas.restore();

    // ── Steel frame border ───────────────────────────────────────────
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 3.5;
    p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF4A4A54),
        Color(0xFF3A3A44),
        Color(0xFF2E2E38),
      ],
    ).createShader(ar);
    canvas.drawRect(ar, p);
    p.style = PaintingStyle.fill;
    p.shader = null;

    // Inner frame highlight
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 0.8;
    p.color = const Color(0x14FFFFFF);
    canvas.drawRect(ar, p);
    p.style = PaintingStyle.fill;

    // ── Perforated steel uprights (left + right) ─────────────────────
    _drawUpright(canvas, Rect.fromLTWH(ar.left - 12, ar.top, 12, ar.height));
    _drawUpright(canvas, Rect.fromLTWH(ar.right, ar.top, 12, ar.height));

    // ── Top crossbar ─────────────────────────────────────────────────
    final crossRect = Rect.fromLTWH(ar.left - 12, ar.top - 6, ar.width + 24, 8);
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF4A4A54), Color(0xFF3A3A44)],
    ).createShader(crossRect);
    canvas.drawRect(crossRect, p);
    p.shader = null;
    // Highlight
    p.color = const Color(0x12FFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(crossRect.left + 2, crossRect.top, crossRect.width - 4, 1.5),
      p,
    );

    // ── Bottom crossbar ──────────────────────────────────────────────
    final baseRect = Rect.fromLTWH(ar.left - 12, ar.bottom, ar.width + 24, 8);
    p.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3A3A44), Color(0xFF2E2E38)],
    ).createShader(baseRect);
    canvas.drawRect(baseRect, p);
    p.shader = null;
    // Highlight
    p.color = const Color(0x12FFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(baseRect.left + 2, baseRect.top, baseRect.width - 4, 1.5),
      p,
    );

    // ── Corner bolts ─────────────────────────────────────────────────
    for (final offset in [
      Offset(ar.left - 6, ar.top - 2),
      Offset(ar.right + 6, ar.top - 2),
      Offset(ar.left - 6, ar.bottom + 4),
      Offset(ar.right + 6, ar.bottom + 4),
    ]) {
      // Bolt circle
      p.color = const Color(0xFF5A5A64);
      canvas.drawCircle(offset, 3.0, p);
      // Bolt highlight
      p.color = const Color(0x25FFFFFF);
      canvas.drawCircle(Offset(offset.dx - 0.5, offset.dy - 0.5), 1.2, p);
    }
  }

  void _drawInteriorBlocks(Canvas canvas, Rect ar) {
    final p = Paint();
    final rng = math.Random(55);
    double y = ar.top;
    int rowSeed = 0;
    while (y < ar.bottom) {
      final rowH = 18.0 + rng.nextDouble() * 10;
      const mortar = 1.2;
      double x = ar.left;
      if (rowSeed % 2 == 1) x -= 12 + rng.nextDouble() * 18;
      while (x < ar.right) {
        final bw = 35.0 + rng.nextDouble() * 30;
        final v = rng.nextDouble();
        p.color = Color.fromRGBO(
          (26 + 12 * v).round(),
          (26 + 12 * v).round(),
          (30 + 14 * v).round(),
          1,
        );
        canvas.drawRect(
          Rect.fromLTWH(x + mortar, y + mortar, bw - mortar * 2, rowH - mortar * 2),
          p,
        );
        p.color = const Color(0xFF0A0A0E);
        canvas.drawRect(Rect.fromLTWH(x + bw - mortar, y, mortar * 2, rowH), p);
        x += bw;
      }
      p.color = const Color(0xFF0A0A0E);
      canvas.drawRect(Rect.fromLTWH(ar.left, y + rowH - mortar, ar.width, mortar * 2), p);
      y += rowH;
      rowSeed++;
    }
  }

  void _drawUpright(Canvas canvas, Rect r) {
    final p = Paint();
    // Upright body (galvanised steel gradient)
    p.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Color(0xFF2E2E38),
        Color(0xFF3E3E48),
        Color(0xFF4A4A54),
        Color(0xFF3E3E48),
        Color(0xFF2E2E38),
      ],
      stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
    ).createShader(r);
    canvas.drawRect(r, p);
    p.shader = null;

    // Centre highlight strip
    p.color = const Color(0x10FFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(r.left + r.width * 0.3, r.top, r.width * 0.4, r.height),
      p,
    );

    // Perforations (evenly spaced holes)
    final holeSpacing = 14.0;
    p.color = const Color(0xFF18181E);
    final holeCx = r.center.dx;
    for (double hy = r.top + 8; hy < r.bottom - 4; hy += holeSpacing) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(holeCx, hy), width: 4, height: 6),
          const Radius.circular(1.5),
        ),
        p,
      );
      // Hole shadow
      p.color = const Color(0x0CFFFFFF);
      canvas.drawRect(
        Rect.fromLTWH(holeCx - 2, hy - 3, 4, 0.8),
        p,
      );
      p.color = const Color(0xFF18181E);
    }
  }

  @override
  bool shouldRepaint(covariant _GarageFramePainter old) =>
      old.alcoveRect != alcoveRect;
}

/// Draws galvanised steel shelves between each row of the grid,
/// with cold LED strip backlighting under each shelf.
class _SteelShelfPainter extends CustomPainter {
  final int rows;
  final double cellHeight;
  final double rowGap;
  final double rowNumWidth;
  final double gridWidth;

  const _SteelShelfPainter({
    required this.rows,
    required this.cellHeight,
    required this.rowGap,
    required this.rowNumWidth,
    required this.gridWidth,
  });

  static const Color _coldBlue = Color(0xFF8AC4E8);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final shelfHeight = math.max(rowGap * 0.92, 6.0);
    final railLeft = rowNumWidth + 2;
    final railWidth = gridWidth - rowNumWidth - 4;

    for (int r = 0; r < rows; r++) {
      final y = (r + 1) * (cellHeight + rowGap) - rowGap + 1;

      // Steel shelf gradient (cold galvanised metal)
      p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF5A5A64),
          Color(0xFF4A4A54),
          Color(0xFF3A3A44),
          Color(0xFF2E2E38),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(railLeft, y, railWidth, shelfHeight));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(railLeft, y, railWidth, shelfHeight),
          const Radius.circular(1.0),
        ),
        p,
      );
      p.shader = null;

      // Wire mesh pattern on shelf surface
      final rng = math.Random(y.toInt() + 300);
      p.color = const Color(0x12000000);
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 0.3;
      for (double gx = railLeft + 4;
          gx < railLeft + railWidth - 4;
          gx += 6 + rng.nextDouble() * 4) {
        canvas.drawLine(
          Offset(gx, y + 1),
          Offset(gx, y + shelfHeight - 1),
          p,
        );
      }
      p.style = PaintingStyle.fill;

      // Top highlight (light on metal edge)
      p.color = const Color(0x20FFFFFF);
      canvas.drawRect(
        Rect.fromLTWH(railLeft + 1, y, railWidth - 2, 1.2),
        p,
      );

      // Bracket ends (small L-shaped supports)
      for (final bx in [railLeft, railLeft + railWidth - 6.0]) {
        p.shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A4A54), Color(0xFF2E2E38)],
        ).createShader(Rect.fromLTWH(bx, y + shelfHeight, 6, 4));
        canvas.drawRect(Rect.fromLTWH(bx, y + shelfHeight, 6, 4), p);
        p.shader = null;
      }

      // Underside shadow
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

      // Cold LED strip glow above shelf (blue-white backlight)
      p.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          _coldBlue.withValues(alpha: 0.08),
          const Color(0x00000000),
        ],
      ).createShader(
        Rect.fromLTWH(railLeft, y - 14, railWidth, 14),
      );
      canvas.drawRect(
        Rect.fromLTWH(railLeft, y - 14, railWidth, 14),
        p,
      );
      p.shader = null;
    }
  }

  @override
  bool shouldRepaint(covariant _SteelShelfPainter old) =>
      old.rows != rows ||
      old.cellHeight != cellHeight ||
      old.rowGap != rowGap ||
      old.gridWidth != gridWidth;
}
