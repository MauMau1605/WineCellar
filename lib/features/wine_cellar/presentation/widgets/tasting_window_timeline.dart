import 'package:flutter/material.dart';

/// A horizontal timeline bar showing the wine's tasting window.
///
/// Displays a gradient bar from the vintage year to beyond drinkUntilYear,
/// with markers for drinkFrom, drinkUntil, and the current year.
class TastingWindowTimeline extends StatelessWidget {
  final int? vintage;
  final int? drinkFromYear;
  final int? drinkUntilYear;

  const TastingWindowTimeline({
    super.key,
    this.vintage,
    this.drinkFromYear,
    this.drinkUntilYear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentYear = DateTime.now().year;

    // Need at least one boundary to render
    if (drinkFromYear == null && drinkUntilYear == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Fenêtre de dégustation inconnue',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final startYear = vintage ?? (drinkFromYear ?? currentYear) - 5;
    final endYear = (drinkUntilYear ?? currentYear) + 5;
    final totalSpan = (endYear - startYear).toDouble();
    if (totalSpan <= 0) return const SizedBox.shrink();

    final drinkFrom = drinkFromYear ?? startYear;
    final drinkUntil = drinkUntilYear ?? endYear;

    // Positions as fractions
    double fraction(int year) =>
        ((year - startYear) / totalSpan).clamp(0.0, 1.0);

    final fromFrac = fraction(drinkFrom);
    final untilFrac = fraction(drinkUntil);
    final currentFrac = fraction(currentYear);

    // Build year labels
    final labelYears = _buildLabelYears(startYear, endYear, currentYear);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fenêtre de dégustation',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return CustomPaint(
                size: Size(width, 32),
                painter: _TimelinePainter(
                  fromFraction: fromFrac,
                  untilFraction: untilFrac,
                  currentFraction: currentFrac,
                  activeColor: _statusColor(currentYear, drinkFrom, drinkUntil),
                  trackColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  markerColor: theme.colorScheme.onSurface,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        // Year labels
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 16,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: labelYears.map((year) {
                  final frac = fraction(year);
                  return Positioned(
                    left: (frac * width) - 16,
                    child: SizedBox(
                      width: 32,
                      child: Text(
                        '$year',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: year == currentYear
                              ? _statusColor(currentYear, drinkFrom, drinkUntil)
                              : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                          fontWeight: year == currentYear
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  List<int> _buildLabelYears(int startYear, int endYear, int currentYear) {
    final labels = <int>{};
    if (vintage != null) labels.add(vintage!);
    if (drinkFromYear != null) labels.add(drinkFromYear!);
    if (drinkUntilYear != null) labels.add(drinkUntilYear!);
    labels.add(currentYear);

    // Ensure no labels are too close (< 3 year gap)
    final sorted = labels.toList()..sort();
    final filtered = <int>[];
    for (final year in sorted) {
      if (filtered.isEmpty || year - filtered.last >= 3) {
        filtered.add(year);
      } else if (year == currentYear) {
        // Always keep current year, remove previous if too close
        if (filtered.isNotEmpty && filtered.last != vintage) {
          filtered.removeLast();
        }
        filtered.add(year);
      }
    }
    return filtered;
  }

  Color _statusColor(int current, int from, int until) {
    if (current < from) return Colors.blue;
    if (current > until) return const Color(0xFFE57373);
    final window = until - from;
    final peakStart = until - (window * 0.3).round();
    if (current >= peakStart) return Colors.amber;
    return Colors.green;
  }
}

class _TimelinePainter extends CustomPainter {
  final double fromFraction;
  final double untilFraction;
  final double currentFraction;
  final Color activeColor;
  final Color trackColor;
  final Color markerColor;

  _TimelinePainter({
    required this.fromFraction,
    required this.untilFraction,
    required this.currentFraction,
    required this.activeColor,
    required this.trackColor,
    required this.markerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = 6.0;
    final trackY = size.height / 2;
    final trackRadius = Radius.circular(trackHeight / 2);

    // Background track
    final bgPaint = Paint()..color = trackColor;
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        trackY - trackHeight / 2,
        size.width,
        trackY + trackHeight / 2,
        trackRadius,
      ),
      bgPaint,
    );

    // Active window
    final fromX = fromFraction * size.width;
    final untilX = untilFraction * size.width;
    final activePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          activeColor.withValues(alpha: 0.4),
          activeColor,
          activeColor.withValues(alpha: 0.4),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(fromX, 0, untilX - fromX, size.height));

    canvas.drawRRect(
      RRect.fromLTRBR(
        fromX,
        trackY - trackHeight / 2,
        untilX,
        trackY + trackHeight / 2,
        trackRadius,
      ),
      activePaint,
    );

    // Current year marker (circle)
    final currentX = currentFraction * size.width;
    final markerRadius = 7.0;

    // White outline
    canvas.drawCircle(
      Offset(currentX, trackY),
      markerRadius + 1.5,
      Paint()..color = markerColor.withValues(alpha: 0.3),
    );

    // Filled circle
    canvas.drawCircle(
      Offset(currentX, trackY),
      markerRadius,
      Paint()..color = activeColor,
    );

    // Inner highlight
    canvas.drawCircle(
      Offset(currentX, trackY),
      3.0,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      fromFraction != oldDelegate.fromFraction ||
      untilFraction != oldDelegate.untilFraction ||
      currentFraction != oldDelegate.currentFraction ||
      activeColor != oldDelegate.activeColor;
}
