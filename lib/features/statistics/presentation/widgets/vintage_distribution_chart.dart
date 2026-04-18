import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_donut_chart.dart';

/// Chart showing the distribution of wines by vintage year.
class VintageDistributionChart extends StatelessWidget {
  final List<VintageStat> data;
  final bool _showAsPie;

  const VintageDistributionChart({super.key, required this.data})
      : _showAsPie = false;

  const VintageDistributionChart.asPie({super.key, required this.data})
      : _showAsPie = true;

  static const _pieColors = [
    Color(0xFF1976D2),
    Color(0xFFD32F2F),
    Color(0xFF388E3C),
    Color(0xFFF57C00),
    Color(0xFF7B1FA2),
    Color(0xFF00838F),
    Color(0xFFC2185B),
    Color(0xFF5D4037),
    Color(0xFF455A64),
    Color(0xFFAFB42B),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucun millésime renseigné')),
      );
    }

    if (_showAsPie) {
      final totalBottles = data.fold<int>(0, (s, e) => s + e.bottles);
      final segments = data.asMap().entries.map((e) {
        final pct = totalBottles > 0
            ? (e.value.bottles / totalBottles * 100)
            : 0.0;
        return DonutSegment(
          label: '${e.value.vintage}',
          value: pct,
          count: e.value.bottles,
          color: _pieColors[e.key % _pieColors.length],
        );
      }).toList();

      return StatDonutChart(
        segments: segments,
        centerLabel: '$totalBottles\nbtl',
      );
    }

    final items = data
        .map((v) =>
            BarItem(label: '${v.vintage}', value: v.bottles.toDouble()))
        .toList();

    return StatVerticalBarChart(
      items: items,
      barColor: theme.colorScheme.secondary,
    );
  }
}
