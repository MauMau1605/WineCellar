import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'premium_cave_background_painter.dart';

/// Wraps the interactive cellar grid inside a premium wine-cave visual.
///
/// The layout computes the glass-area size from the grid dimensions,
/// draws the cave decor behind it, and overlays the [gridChild] on top
/// of the glass area. Wood shelf rails are drawn between rows.
class PremiumCaveWrapper extends StatelessWidget {
  /// The interactive grid widget (Column of rows of _SlotCell widgets).
  final Widget gridChild;

  /// Number of columns in the cellar.
  final int columns;

  /// Number of rows in the cellar.
  final int rows;

  /// Current pixel width of a single cell.
  final double cellWidth;

  /// Current pixel height of a single cell.
  final double cellHeight;

  /// Current pixel width of the row-number label column.
  final double rowNumWidth;

  /// Vertical gap between rows.
  final double rowGap;

  const PremiumCaveWrapper({
    super.key,
    required this.gridChild,
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.rowNumWidth,
    required this.rowGap,
  });

  @override
  Widget build(BuildContext context) {
    // Glass area dimensions – just enough to contain the grid.
    // Extra padding for visual breathing room inside the glass.
    const glassPadH = 8.0; // horizontal padding
    const glassPadV = 10.0; // vertical padding

    final gridWidth = rowNumWidth + columns * cellWidth;
    final gridHeight = rows * (cellHeight + rowGap);

    final glassWidth = gridWidth + glassPadH * 2;
    final glassHeight = gridHeight + glassPadV * 2;

    // Frame and overall canvas sizing
    const frameInsetX = PremiumCaveBackgroundPainter.frameInsetX;
    const frameInsetTop = PremiumCaveBackgroundPainter.frameInsetTop;
    const frameInsetBottom = PremiumCaveBackgroundPainter.frameInsetBottom;
    const basePadX = PremiumCaveBackgroundPainter.basePadX;
    const baseHeight = PremiumCaveBackgroundPainter.baseHeight;
    const baseGap = PremiumCaveBackgroundPainter.baseGap;

    // Canvas must hold: frame + base + some ambient-glow bleed
    const ambientBleed = 50.0;
    final canvasWidth =
        glassWidth + frameInsetX * 2 + basePadX * 2 + ambientBleed;
    final canvasHeight =
        glassHeight + frameInsetTop + frameInsetBottom + baseGap + baseHeight + ambientBleed;

    // Glass rect origin within the canvas
    final glassLeft = (canvasWidth - glassWidth) / 2;
    final glassTop = frameInsetTop + (ambientBleed / 4);

    final glassRect = Rect.fromLTWH(
      glassLeft,
      glassTop,
      glassWidth,
      glassHeight,
    );

    return SizedBox(
      width: canvasWidth,
      height: canvasHeight,
      child: Stack(
        children: [
          // Background decor
          Positioned.fill(
            child: CustomPaint(
              painter: PremiumCaveBackgroundPainter(glassRect: glassRect),
            ),
          ),
          // Wood shelf rails drawn on top of glass background,
          // behind the grid slots
          Positioned(
            left: glassRect.left + glassPadH,
            top: glassRect.top + glassPadV,
            width: gridWidth,
            height: gridHeight,
            child: CustomPaint(
              painter: _ShelfRailPainter(
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
            left: glassRect.left + glassPadH,
            top: glassRect.top + glassPadV,
            width: gridWidth,
            height: gridHeight,
            child: gridChild,
          ),
        ],
      ),
    );
  }
}

/// Draws light-oak shelf rails between each row of the grid.
class _ShelfRailPainter extends CustomPainter {
  final int rows;
  final double cellHeight;
  final double rowGap;
  final double rowNumWidth;
  final double gridWidth;

  const _ShelfRailPainter({
    required this.rows,
    required this.cellHeight,
    required this.rowGap,
    required this.rowNumWidth,
    required this.gridWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final railHeight = math.max(rowGap * 0.9, 5.0);
    final railLeft = rowNumWidth + 2;
    final railWidth = gridWidth - rowNumWidth - 4;

    for (int r = 0; r < rows; r++) {
      // Rail sits right below each row of cells
      final y = (r + 1) * (cellHeight + rowGap) - rowGap + 1;

      // Wood gradient
      p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFFCA9244),
          Color(0xFFA0682C),
          Color(0xFF6E4418),
        ],
      ).createShader(Rect.fromLTWH(railLeft, y, railWidth, railHeight));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(railLeft, y, railWidth, railHeight),
          const Radius.circular(1.5),
        ),
        p,
      );
      p.shader = null;

      // Grain lines
      final rng = math.Random(y.toInt());
      p.color = const Color(0x20000000);
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 0.4;
      for (double gx = railLeft + 6;
          gx < railLeft + railWidth - 4;
          gx += 8 + rng.nextDouble() * 8) {
        canvas.drawLine(Offset(gx, y),
            Offset(gx + 1.5 + rng.nextDouble() * 1.5, y + railHeight), p);
      }
      p.style = PaintingStyle.fill;

      // Top highlight
      p.color = const Color(0x18FFFFFF);
      canvas.drawRect(
          Rect.fromLTWH(railLeft + 2, y, railWidth - 4, 1.2), p);

      // Bottom shadow
      p.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x28000000), Color(0x00000000)],
      ).createShader(
          Rect.fromLTWH(railLeft, y + railHeight, railWidth, 3));
      canvas.drawRect(
          Rect.fromLTWH(railLeft, y + railHeight, railWidth, 3), p);
      p.shader = null;
    }
  }

  @override
  bool shouldRepaint(covariant _ShelfRailPainter old) =>
      old.rows != rows ||
      old.cellHeight != cellHeight ||
      old.rowGap != rowGap ||
      old.gridWidth != gridWidth;
}
