import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/helpers/overview_section_helper.dart';

/// Overview section displaying key KPI cards.
class OverviewSection extends StatelessWidget {
  final OverviewStats stats;

  const OverviewSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = OverviewSectionHelper.buildCards(
      stats,
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            OverviewSectionHelper.crossAxisCountForWidth(constraints.maxWidth);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: cards.map((kpi) => _KpiCard(data: kpi)).toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final OverviewKpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, color: data.color, size: 28),
            const SizedBox(height: 6),
            Text(
              data.value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              data.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
