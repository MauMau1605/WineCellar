import 'package:flutter/material.dart';

import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_donut_chart.dart';

/// Donut chart showing the distribution of wines by color.
class ColorDistributionChart extends StatelessWidget {
  final List<ColorStat> data;

  const ColorDistributionChart({super.key, required this.data});

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
}
