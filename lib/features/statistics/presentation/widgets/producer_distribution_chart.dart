import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_donut_chart.dart';

/// Chart showing the top producers.
class ProducerDistributionChart extends StatelessWidget {
  final List<ProducerStat> data;
  final bool _showAsPie;

  const ProducerDistributionChart({super.key, required this.data})
      : _showAsPie = false;

  const ProducerDistributionChart.asPie({super.key, required this.data})
      : _showAsPie = true;

  static const _pieColors = [
    Color(0xFF5D4037),
    Color(0xFF1976D2),
    Color(0xFFD32F2F),
    Color(0xFF388E3C),
    Color(0xFFF57C00),
    Color(0xFF7B1FA2),
    Color(0xFF00838F),
    Color(0xFFC2185B),
    Color(0xFF455A64),
    Color(0xFFAFB42B),
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucun producteur renseigné')),
      );
    }

    if (_showAsPie) {
      final totalBottles = data.fold<int>(0, (s, e) => s + e.bottles);
      final segments = data.asMap().entries.map((e) {
        return DonutSegment(
          label: e.value.producer,
          value: e.value.percentage,
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
        .map((p) => BarItem(label: p.producer, value: p.bottles.toDouble()))
        .toList();

    return StatBarChart(
      items: items,
      barColor: const Color(0xFF5D4037),
      maxItems: 12,
    );
  }
}
