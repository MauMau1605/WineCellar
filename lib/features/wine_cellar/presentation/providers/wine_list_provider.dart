import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';

/// Provider that watches wines with a given filter
final filteredWinesProvider =
    StreamProvider.family<List<WineEntity>, WineFilter>((ref, filter) {
  final repo = ref.watch(wineRepositoryProvider);
  return repo.watchFilteredWines(filter);
});

/// Provider for all wines (no filter)
final allWinesProvider = StreamProvider<List<WineEntity>>((ref) {
  final repo = ref.watch(wineRepositoryProvider);
  return repo.watchAllWines();
});

/// Stats providers
final wineCountProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(wineRepositoryProvider);
  return repo.getWineCount();
});

final totalBottlesProvider = FutureProvider<int>((ref) {
  final repo = ref.watch(wineRepositoryProvider);
  return repo.getTotalBottles();
});
