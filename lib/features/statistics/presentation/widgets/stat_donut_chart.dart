import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A generic reusable donut chart widget.
///
/// Each [DonutSegment] maps to a pie section with label, value, color, and
/// optional emoji. Segments below [groupThresholdPercent] are merged into
/// an "Autres" group to keep the chart readable.
class StatDonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;
  final String? centerLabel;
  final double groupThresholdPercent;
  final int maxSegments;

  const StatDonutChart({
    super.key,
    required this.segments,
    this.size = 200,
    this.centerLabel,
    this.groupThresholdPercent = 3.0,
    this.maxSegments = 8,
  });

  List<DonutSegment> _groupedSegments() {
    if (segments.length <= maxSegments) return segments;
    final sorted = [...segments]
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(maxSegments - 1).toList();
    final rest = sorted.skip(maxSegments - 1).toList();
    if (rest.isEmpty) return top;
    final otherValue = rest.fold<double>(0, (s, e) => s + e.value);
    final otherCount = rest.fold<int>(0, (s, e) => s + e.count);
    return [
      ...top,
      DonutSegment(
        label: 'Autres',
        value: otherValue,
        count: otherCount,
        color: Colors.grey,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('Aucune donnée')),
      );
    }

    final theme = Theme.of(context);
    final displaySegments = _groupedSegments();

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
                  sections: displaySegments.map((s) {
                    final showLabel = s.value >= 5;
                    return PieChartSectionData(
                      value: s.value,
                      color: s.color,
                      radius: size / 4,
                      title: showLabel
                          ? '${s.count}\n${s.value.toStringAsFixed(1)}%'
                          : '',
                      titleStyle: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        height: 1.2,
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
          children:
              displaySegments.map((s) => _LegendItem(segment: s)).toList(),
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
          '(${segment.count} — ${segment.value.toStringAsFixed(1)}%)',
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
