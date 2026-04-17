import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';

/// Horizontal bar chart showing the top producers.
class ProducerDistributionChart extends StatelessWidget {
  final List<ProducerStat> data;

  const ProducerDistributionChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucun producteur renseigné')),
      );
    }

    final items = data
        .map((p) => BarItem(label: p.producer, value: p.bottles.toDouble()))
        .toList();

    return StatBarChart(
      items: items,
      barColor: const Color(0xFF5D4037),
      maxItems: 12,
    );
  }
}
