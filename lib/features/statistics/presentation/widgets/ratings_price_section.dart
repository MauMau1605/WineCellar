import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';

/// Combined section for ratings and price statistics.
class RatingsPriceSection extends StatefulWidget {
  final List<RatingStat> ratingData;
  final PriceStats priceStats;

  const RatingsPriceSection({
    super.key,
    required this.ratingData,
    required this.priceStats,
  });

  @override
  State<RatingsPriceSection> createState() => _RatingsPriceSectionState();
}

class _RatingsPriceSectionState extends State<RatingsPriceSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ChoiceChip(
              label: const Text('Notes'),
              selected: _tab == 0,
              onSelected: (_) => setState(() => _tab = 0),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Prix'),
              selected: _tab == 1,
              onSelected: (_) => setState(() => _tab = 1),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_tab == 0) _RatingChart(data: widget.ratingData),
        if (_tab == 1) _PriceSection(stats: widget.priceStats),
      ],
    );
  }
}

class _RatingChart extends StatelessWidget {
  final List<RatingStat> data;

  const _RatingChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRatings = data.any((r) => r.bottles > 0);

    if (!hasRatings) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucune note attribuée')),
      );
    }

    final maxVal =
        data.fold<int>(0, (m, r) => r.bottles > m ? r.bottles : m);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.15,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final stars = '★' * group.x;
                return BarTooltipItem(
                  '$stars\n${rod.toY.round()} btl',
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
                reservedSize: 28,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final v = value.toInt();
                  if (v == 0) return const Text('N/A');
                  return Text(
                    '★' * v,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.secondary,
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
          barGroups: data.map((r) {
            return BarChartGroupData(
              x: r.rating,
              barRods: [
                BarChartRodData(
                  toY: r.bottles.toDouble(),
                  color: const Color(0xFFFFC107),
                  width: 24,
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

class _PriceSection extends StatelessWidget {
  final PriceStats stats;

  const _PriceSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!stats.hasData) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Aucun prix renseigné')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI row
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _PriceKpi(label: 'Min', value: '${stats.minPrice!.toStringAsFixed(0)} €'),
            _PriceKpi(label: 'Médian', value: '${stats.medianPrice!.toStringAsFixed(0)} €'),
            _PriceKpi(label: 'Moyen', value: '${stats.averagePrice!.toStringAsFixed(1)} €'),
            _PriceKpi(label: 'Max', value: '${stats.maxPrice!.toStringAsFixed(0)} €'),
            _PriceKpi(
              label: 'Valeur totale',
              value: '${stats.totalValue!.toStringAsFixed(0)} €',
              highlight: true,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Répartition par tranche de prix',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        StatBarChart(
          items: stats.priceRanges
              .map((r) => BarItem(label: r.label, value: r.bottles.toDouble()))
              .toList(),
          barColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }
}

class _PriceKpi extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _PriceKpi({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
