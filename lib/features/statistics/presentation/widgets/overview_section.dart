import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';

/// Overview section displaying key KPI cards.
class OverviewSection extends StatelessWidget {
  final OverviewStats stats;

  const OverviewSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = <_KpiData>[
      _KpiData(
        icon: Icons.wine_bar,
        label: 'Références',
        value: '${stats.totalReferences}',
        color: theme.colorScheme.primary,
      ),
      _KpiData(
        icon: Icons.inventory_2,
        label: 'Bouteilles',
        value: '${stats.totalBottles}',
        color: theme.colorScheme.secondary,
      ),
      if (stats.totalValue != null)
        _KpiData(
          icon: Icons.euro,
          label: 'Valeur estimée',
          value: '${stats.totalValue!.toStringAsFixed(0)} €',
          color: const Color(0xFF4CAF50),
        ),
      if (stats.averagePrice != null)
        _KpiData(
          icon: Icons.price_change_outlined,
          label: 'Prix moyen',
          value: '${stats.averagePrice!.toStringAsFixed(1)} €',
          color: const Color(0xFF2196F3),
        ),
      if (stats.averageRating != null)
        _KpiData(
          icon: Icons.star,
          label: 'Note moyenne',
          value: '${stats.averageRating!.toStringAsFixed(1)} / 5',
          color: const Color(0xFFFFC107),
        ),
      if (stats.oldestVintage != null && stats.newestVintage != null)
        _KpiData(
          icon: Icons.date_range,
          label: 'Millésimes',
          value: '${stats.oldestVintage} – ${stats.newestVintage}',
          color: const Color(0xFF9C27B0),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
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

class _KpiData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;

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
