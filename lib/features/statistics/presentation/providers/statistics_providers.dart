import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/domain/usecases/get_cellar_statistics.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';

// ── Use Case ────────────────────────────────────────────────────────────

final getCellarStatisticsUseCaseProvider =
    Provider<GetCellarStatisticsUseCase>((ref) {
  return GetCellarStatisticsUseCase(ref.watch(statisticsRepositoryProvider));
});

// ── Statistics state ────────────────────────────────────────────────────

/// Provides cellar statistics. Automatically refreshes when wines change.
final cellarStatisticsProvider = FutureProvider<CellarStatistics>((ref) async {
  // Watch the wine stream so statistics refresh when wines change.
  ref.watch(allWinesStreamProvider);
  final useCase = ref.watch(getCellarStatisticsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (stats) => stats,
  );
});

/// Internal: watch the wine stream purely for invalidation.
final allWinesStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(wineRepositoryProvider);
  return repo.watchAllWines().map((_) {});
});

/// Currently selected statistics category.
enum StatCategory {
  overview,
  color,
  maturity,
  geography,
  vintages,
  grapes,
  ratingsPrice,
  producers;

  String get label {
    switch (this) {
      case StatCategory.overview:
        return 'Vue d\'ensemble';
      case StatCategory.color:
        return 'Couleur';
      case StatCategory.maturity:
        return 'Maturité';
      case StatCategory.geography:
        return 'Géographie';
      case StatCategory.vintages:
        return 'Millésimes';
      case StatCategory.grapes:
        return 'Cépages';
      case StatCategory.ratingsPrice:
        return 'Notes & Prix';
      case StatCategory.producers:
        return 'Producteurs';
    }
  }
}

final selectedStatCategoryProvider =
    StateProvider<StatCategory>((ref) => StatCategory.overview);

/// Whether to show pie chart (true) or bar chart (false) per category.
final chartModePieProvider =
    StateProvider.family<bool, StatCategory>((ref, category) {
  // Default: donut for color/maturity, bar for the rest
  return category == StatCategory.color ||
      category == StatCategory.maturity;
});
