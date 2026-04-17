import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_donut_chart.dart';

/// Donut chart showing the distribution of wines by maturity stage.
class MaturityDistributionChart extends StatelessWidget {
  final List<MaturityStat> data;

  const MaturityDistributionChart({super.key, required this.data});

  static const _maturityColors = {
    'Trop jeune': Color(0xFF42A5F5), // blue
    'Prêt à boire': Color(0xFF66BB6A), // green
    'À son apogée': Color(0xFFFFC107), // amber
    'Passé': Color(0xFFEF5350), // red
    'Inconnu': Color(0xFF9E9E9E), // grey
  };

  @override
  Widget build(BuildContext context) {
    final totalBottles = data.fold<int>(0, (s, e) => s + e.bottles);
    final segments = data.map((m) {
      return DonutSegment(
        label: m.maturityName,
        emoji: m.emoji,
        value: m.percentage,
        count: m.bottles,
        color: _maturityColors[m.maturityName] ?? Colors.grey,
      );
    }).toList();

    return StatDonutChart(
      segments: segments,
      centerLabel: '$totalBottles\nbtl',
    );
  }
}
