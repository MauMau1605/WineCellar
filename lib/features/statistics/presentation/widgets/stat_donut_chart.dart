import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A generic reusable donut chart widget.
///
/// Each [DonutSegment] maps to a pie section with label, value, color, and
/// optional emoji.
class StatDonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;
  final String? centerLabel;

  const StatDonutChart({
    super.key,
    required this.segments,
    this.size = 200,
    this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('Aucune donnée')),
      );
    }

    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: segments.map((s) {
                    return PieChartSectionData(
                      value: s.value,
                      color: s.color,
                      radius: size / 4,
                      title: s.value >= 5
                          ? '${s.value.toStringAsFixed(1)}%'
                          : '',
                      titleStyle: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      titlePositionPercentageOffset: 0.55,
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: size / 4,
                  startDegreeOffset: -90,
                ),
              ),
              if (centerLabel != null)
                Text(
                  centerLabel!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: segments.map((s) => _LegendItem(segment: s)).toList(),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final DonutSegment segment;

  const _LegendItem({required this.segment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: segment.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          segment.emoji != null
              ? '${segment.emoji} ${segment.label}'
              : segment.label,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(width: 2),
        Text(
          '(${segment.count})',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// A single segment in the donut chart.
class DonutSegment {
  final String label;
  final String? emoji;
  final double value; // percentage
  final int count; // bottle count
  final Color color;

  const DonutSegment({
    required this.label,
    this.emoji,
    required this.value,
    required this.count,
    required this.color,
  });
}
