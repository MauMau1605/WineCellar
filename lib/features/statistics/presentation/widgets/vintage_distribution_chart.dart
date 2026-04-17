import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';

/// Vertical bar chart showing the distribution of wines by vintage year.
class VintageDistributionChart extends StatelessWidget {
  final List<VintageStat> data;

  const VintageDistributionChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucun millésime renseigné')),
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
