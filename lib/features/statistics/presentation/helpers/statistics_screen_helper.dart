import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/presentation/providers/statistics_providers.dart';

class StatCategoryUiConfig {
  final StatCategory category;
  final String sectionTitle;
  final IconData icon;
  final bool supportsChartToggle;

  const StatCategoryUiConfig({
    required this.category,
    required this.sectionTitle,
    required this.icon,
    required this.supportsChartToggle,
  });
}

class StatisticsScreenHelper {
  StatisticsScreenHelper._();

  static const String errorTitle = 'Impossible de charger les statistiques';
  static const String emptyTitle = 'Aucun vin dans la cave';
  static const String emptyDescription =
      'Ajoutez des vins pour voir les statistiques de votre cave.';

  static const List<StatCategoryUiConfig> categories = [
    StatCategoryUiConfig(
      category: StatCategory.overview,
      sectionTitle: 'Vue d\'ensemble',
      icon: Icons.dashboard,
      supportsChartToggle: false,
    ),
    StatCategoryUiConfig(
      category: StatCategory.color,
      sectionTitle: 'Répartition par couleur',
      icon: Icons.palette,
      supportsChartToggle: true,
    ),
    StatCategoryUiConfig(
      category: StatCategory.maturity,
      sectionTitle: 'Stade de maturité',
      icon: Icons.timelapse,
      supportsChartToggle: true,
    ),
    StatCategoryUiConfig(
      category: StatCategory.geography,
      sectionTitle: 'Géographie',
      icon: Icons.public,
      supportsChartToggle: true,
    ),
    StatCategoryUiConfig(
      category: StatCategory.vintages,
      sectionTitle: 'Distribution des millésimes',
      icon: Icons.calendar_today,
      supportsChartToggle: true,
    ),
    StatCategoryUiConfig(
      category: StatCategory.grapes,
      sectionTitle: 'Cépages',
      icon: Icons.grass,
      supportsChartToggle: true,
    ),
    StatCategoryUiConfig(
      category: StatCategory.ratingsPrice,
      sectionTitle: 'Notes & Prix',
      icon: Icons.star,
      supportsChartToggle: false,
    ),
    StatCategoryUiConfig(
      category: StatCategory.producers,
      sectionTitle: 'Producteurs',
      icon: Icons.business,
      supportsChartToggle: true,
    ),
  ];

  static StatCategoryUiConfig configFor(StatCategory category) {
    return categories.firstWhere((config) => config.category == category);
  }

  static IconData chipIconFor(StatCategory category) {
    return configFor(category).icon;
  }

  static bool shouldShowChartToggle(StatCategory category) {
    return configFor(category).supportsChartToggle;
  }

  static String chartToggleTooltip(bool isPie) {
    return isPie ? 'Voir en barres' : 'Voir en camembert';
  }
}