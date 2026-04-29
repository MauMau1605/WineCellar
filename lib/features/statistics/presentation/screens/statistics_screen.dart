import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/helpers/statistics_screen_helper.dart';
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
                  StatisticsScreenHelper.errorTitle,
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
                      StatisticsScreenHelper.emptyTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      StatisticsScreenHelper.emptyDescription,
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
                  child: _buildSection(selectedCategory, stats, context, ref),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
      StatCategory category, CellarStatistics stats, BuildContext context,
      WidgetRef ref) {
    final theme = Theme.of(context);
    final isPie = ref.watch(chartModePieProvider(category));
    final config = StatisticsScreenHelper.configFor(category);
    final hasToggle = StatisticsScreenHelper.shouldShowChartToggle(category);

    Widget wrapWithTitle(Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config.icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  config.sectionTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasToggle)
                IconButton(
                  icon: Icon(isPie ? Icons.bar_chart : Icons.pie_chart),
                  tooltip: StatisticsScreenHelper.chartToggleTooltip(isPie),
                  onPressed: () => ref
                      .read(chartModePieProvider(category).notifier)
                      .state = !isPie,
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
          OverviewSection(stats: stats.overview),
        );
      case StatCategory.color:
        return wrapWithTitle(
          isPie
              ? ColorDistributionChart(data: stats.colorDistribution)
              : ColorDistributionChart.asBar(data: stats.colorDistribution),
        );
      case StatCategory.maturity:
        return wrapWithTitle(
          isPie
              ? MaturityDistributionChart(data: stats.maturityDistribution)
              : MaturityDistributionChart.asBar(
                  data: stats.maturityDistribution),
        );
      case StatCategory.geography:
        return wrapWithTitle(
          isPie
              ? GeographySection.asPie(
                  countryData: stats.countryDistribution,
                  regionData: stats.regionDistribution,
                  appellationData: stats.appellationDistribution,
                )
              : GeographySection(
                  countryData: stats.countryDistribution,
                  regionData: stats.regionDistribution,
                  appellationData: stats.appellationDistribution,
                ),
        );
      case StatCategory.vintages:
        return wrapWithTitle(
          isPie
              ? VintageDistributionChart.asPie(data: stats.vintageDistribution)
              : VintageDistributionChart(data: stats.vintageDistribution),
        );
      case StatCategory.grapes:
        return wrapWithTitle(
          isPie
              ? GrapeDistributionChart.asPie(data: stats.grapeDistribution)
              : GrapeDistributionChart(data: stats.grapeDistribution),
        );
      case StatCategory.ratingsPrice:
        return wrapWithTitle(
          RatingsPriceSection(
            ratingData: stats.ratingDistribution,
            priceStats: stats.priceStats,
          ),
        );
      case StatCategory.producers:
        return wrapWithTitle(
          isPie
              ? ProducerDistributionChart.asPie(
                  data: stats.producerDistribution)
              : ProducerDistributionChart(data: stats.producerDistribution),
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
                StatisticsScreenHelper.chipIconFor(cat),
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
