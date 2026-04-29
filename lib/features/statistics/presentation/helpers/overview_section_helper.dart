import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';

class OverviewKpiData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const OverviewKpiData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class OverviewSectionHelper {
  OverviewSectionHelper._();

  static List<OverviewKpiData> buildCards(
    OverviewStats stats,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return [
      OverviewKpiData(
        icon: Icons.wine_bar,
        label: 'Références',
        value: '${stats.totalReferences}',
        color: primaryColor,
      ),
      OverviewKpiData(
        icon: Icons.inventory_2,
        label: 'Bouteilles',
        value: '${stats.totalBottles}',
        color: secondaryColor,
      ),
      if (stats.totalValue != null)
        OverviewKpiData(
          icon: Icons.euro,
          label: 'Valeur estimée',
          value: '${stats.totalValue!.toStringAsFixed(0)} €',
          color: const Color(0xFF4CAF50),
        ),
      if (stats.averagePrice != null)
        OverviewKpiData(
          icon: Icons.price_change_outlined,
          label: 'Prix moyen',
          value: '${stats.averagePrice!.toStringAsFixed(1)} €',
          color: const Color(0xFF2196F3),
        ),
      if (stats.averageRating != null)
        OverviewKpiData(
          icon: Icons.star,
          label: 'Note moyenne',
          value: '${stats.averageRating!.toStringAsFixed(1)} / 5',
          color: const Color(0xFFFFC107),
        ),
      if (stats.oldestVintage != null && stats.newestVintage != null)
        OverviewKpiData(
          icon: Icons.date_range,
          label: 'Millésimes',
          value: '${stats.oldestVintage} – ${stats.newestVintage}',
          color: const Color(0xFF9C27B0),
        ),
    ];
  }

  static int crossAxisCountForWidth(double width) {
    return width > 600 ? 3 : 2;
  }
}