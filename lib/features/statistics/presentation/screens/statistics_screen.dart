import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/color_distribution_chart.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/geography_section.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/grape_distribution_chart.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/maturity_distribution_chart.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/overview_section.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/producer_distribution_chart.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/ratings_price_section.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/vintage_distribution_chart.dart';

/// Main statistics screen with category selector and reactive charts.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cellarStatisticsProvider);
    final selectedCategory = ref.watch(selectedStatCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Impossible de charger les statistiques',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          if (stats.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wine_bar_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun vin dans la cave',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ajoutez des vins pour voir les statistiques de votre cave.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Category selector
              _CategorySelector(
                selected: selectedCategory,
                onSelected: (cat) =>
                    ref.read(selectedStatCategoryProvider.notifier).state = cat,
              ),
              const Divider(height: 1),
              // Section content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildSection(selectedCategory, stats, context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
      StatCategory category, dynamic stats, BuildContext context) {
    final theme = Theme.of(context);

    Widget wrapWithTitle(String title, IconData icon, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      );
    }

    switch (category) {
      case StatCategory.overview:
        return wrapWithTitle(
          'Vue d\'ensemble',
          Icons.dashboard,
          OverviewSection(stats: stats.overview),
        );
      case StatCategory.color:
        return wrapWithTitle(
          'Répartition par couleur',
          Icons.palette,
          ColorDistributionChart(data: stats.colorDistribution),
        );
      case StatCategory.maturity:
        return wrapWithTitle(
          'Stade de maturité',
          Icons.timelapse,
          MaturityDistributionChart(data: stats.maturityDistribution),
        );
      case StatCategory.geography:
        return wrapWithTitle(
          'Géographie',
          Icons.public,
          GeographySection(
            countryData: stats.countryDistribution,
            regionData: stats.regionDistribution,
            appellationData: stats.appellationDistribution,
          ),
        );
      case StatCategory.vintages:
        return wrapWithTitle(
          'Distribution des millésimes',
          Icons.calendar_today,
          VintageDistributionChart(data: stats.vintageDistribution),
        );
      case StatCategory.grapes:
        return wrapWithTitle(
          'Cépages',
          Icons.grass,
          GrapeDistributionChart(data: stats.grapeDistribution),
        );
      case StatCategory.ratingsPrice:
        return wrapWithTitle(
          'Notes & Prix',
          Icons.star,
          RatingsPriceSection(
            ratingData: stats.ratingDistribution,
            priceStats: stats.priceStats,
          ),
        );
      case StatCategory.producers:
        return wrapWithTitle(
          'Producteurs',
          Icons.business,
          ProducerDistributionChart(data: stats.producerDistribution),
        );
    }
  }
}

/// Scrollable horizontal chips for category selection (mobile-friendly).
class _CategorySelector extends StatelessWidget {
  final StatCategory selected;
  final ValueChanged<StatCategory> onSelected;

  const _CategorySelector({
    required this.selected,
    required this.onSelected,
  });

  static const _icons = {
    StatCategory.overview: Icons.dashboard,
    StatCategory.color: Icons.palette,
    StatCategory.maturity: Icons.timelapse,
    StatCategory.geography: Icons.public,
    StatCategory.vintages: Icons.calendar_today,
    StatCategory.grapes: Icons.grass,
    StatCategory.ratingsPrice: Icons.star,
    StatCategory.producers: Icons.business,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: StatCategory.values.map((cat) {
          final isSelected = cat == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                _icons[cat],
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
              label: Text(cat.label),
              selected: isSelected,
              onSelected: (_) => onSelected(cat),
            ),
          );
        }).toList(),
      ),
    );
  }
}
