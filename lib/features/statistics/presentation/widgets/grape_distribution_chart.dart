import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';

/// Horizontal bar chart showing the distribution of grape varieties.
class GrapeDistributionChart extends StatelessWidget {
  final List<GrapeVarietyStat> data;

  const GrapeDistributionChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucun cépage renseigné')),
      );
    }

    final items = data
        .map((g) => BarItem(label: g.grape, value: g.bottles.toDouble()))
        .toList();

    return StatBarChart(
      items: items,
      barColor: const Color(0xFF558B2F),
      maxItems: 12,
    );
  }
}
