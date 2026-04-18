import 'package:flutter/material.dart';

import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_donut_chart.dart';

/// Chart showing the distribution of wines by color.
class ColorDistributionChart extends StatelessWidget {
  final List<ColorStat> data;
  final bool _showAsPie;

  const ColorDistributionChart({super.key, required this.data})
      : _showAsPie = true;

  const ColorDistributionChart.asBar({super.key, required this.data})
      : _showAsPie = false;

  static const _colorMap = {
    'Rouge': 'red',
    'Blanc': 'white',
    'Rosé': 'rose',
    'Pétillant': 'sparkling',
    'Moelleux': 'sweet',
  };

  @override
  Widget build(BuildContext context) {
    final totalBottles = data.fold<int>(0, (s, e) => s + e.bottles);

    if (_showAsPie) {
      final segments = data.map((c) {
        final colorKey = _colorMap[c.colorName] ?? c.colorName.toLowerCase();
        return DonutSegment(
          label: c.colorName,
          emoji: c.emoji,
          value: c.percentage,
          count: c.bottles,
          color: AppTheme.colorForWine(colorKey),
        );
      }).toList();

      return StatDonutChart(
        segments: segments,
        centerLabel: '$totalBottles\nbtl',
      );
    }

    final barItems = data.map((c) {
      final colorKey = _colorMap[c.colorName] ?? c.colorName.toLowerCase();
      return BarItem(
        label: c.colorName,
        value: c.bottles.toDouble(),
        color: AppTheme.colorForWine(colorKey),
      );
    }).toList();

    return StatBarChart(items: barItems, unitSuffix: ' btl');
  }
}
