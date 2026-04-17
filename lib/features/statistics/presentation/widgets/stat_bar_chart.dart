import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A reusable horizontal bar chart for ranked distributions.
///
/// Shows up to [maxItems] bars sorted by value, with optional "Other" grouping.
class StatBarChart extends StatelessWidget {
  final List<BarItem> items;
  final int maxItems;
  final Color? barColor;
  final String? unitSuffix;

  const StatBarChart({
    super.key,
    required this.items,
    this.maxItems = 10,
    this.barColor,
    this.unitSuffix,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucune donnée')),
      );
    }

    final theme = Theme.of(context);
    final color = barColor ?? theme.colorScheme.primary;
    final displayItems = _buildDisplayItems();
    final maxVal =
        displayItems.fold<double>(0, (m, e) => e.value > m ? e.value : m);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: displayItems.asMap().entries.map((entry) {
            final item = entry.value;
            final fraction = maxVal > 0 ? item.value / maxVal : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.30,
                    child: Text(
                      item.label,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          item.color ?? color,
                        ),
                        minHeight: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(
                      unitSuffix != null
                          ? '${item.value.round()}$unitSuffix'
                          : '${item.value.round()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  List<BarItem> _buildDisplayItems() {
    if (items.length <= maxItems) return items;
    final top = items.sublist(0, maxItems - 1);
    final rest = items.sublist(maxItems - 1);
    final otherSum = rest.fold<double>(0, (s, e) => s + e.value);
    return [
      ...top,
      BarItem(label: 'Autres', value: otherSum),
    ];
  }
}

/// A vertical bar chart for timeline/vintage distributions.
class StatVerticalBarChart extends StatelessWidget {
  final List<BarItem> items;
  final Color? barColor;

  const StatVerticalBarChart({
    super.key,
    required this.items,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucune donnée')),
      );
    }

    final theme = Theme.of(context);
    final color = barColor ?? theme.colorScheme.primary;
    final maxVal =
        items.fold<double>(0, (m, e) => e.value > m ? e.value : m);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.15,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = items[groupIndex];
                return BarTooltipItem(
                  '${item.label}\n${rod.toY.round()} btl',
                  theme.textTheme.bodySmall!.copyWith(color: Colors.white),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= items.length) return const SizedBox();
                  // Show every Nth label to avoid overlap
                  final step = (items.length / 8).ceil().clamp(1, 100);
                  if (idx % step != 0) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        items[idx].label,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxVal / 4).ceilToDouble().clamp(1, 10000),
          ),
          borderData: FlBorderData(show: false),
          barGroups: items.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value,
                  color: entry.value.color ?? color,
                  width: items.length > 30
                      ? 6
                      : items.length > 15
                          ? 10
                          : 16,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// A single bar item used by both horizontal and vertical bar charts.
class BarItem {
  final String label;
  final double value;
  final Color? color;

  const BarItem({
    required this.label,
    required this.value,
    this.color,
  });
}
