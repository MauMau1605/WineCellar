import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_sort.dart';

class WineListScreenHelper {
  WineListScreenHelper._();

  static const double autoBreakpoint = 900;
  static const String searchHint = 'Rechercher...';
  static const String emptyTitle = 'Aucun vin dans votre cave';
  static const String emptySubtitle =
      'Utilisez l\'assistant IA pour ajouter votre premier vin';

  static bool computeIsMasterDetail(
    WineListLayout layout,
    double screenWidth, {
    double breakpoint = autoBreakpoint,
  }) {
    return switch (layout) {
      WineListLayout.list => false,
      WineListLayout.masterDetail => true,
      WineListLayout.masterDetailVertical => true,
      WineListLayout.auto => screenWidth >= breakpoint,
    };
  }

  static WineFilter updateSearchFilter(WineFilter current, String value) {
    if (value.isEmpty) {
      return current.copyWith(clearSearch: true);
    }
    return current.copyWith(
      searchQuery: value,
      clearColor: true,
      clearMaturity: true,
    );
  }

  static List<WineEntity> applyClientSideFiltersAndSort(
    List<WineEntity> wines,
    WineFilter filter,
    WineSort? sort,
  ) {
    var filtered = filter.maturity != null
        ? wines.where((wine) => wine.maturity == filter.maturity).toList()
        : List<WineEntity>.from(wines);

    if (filter.locations.isNotEmpty) {
      filtered = filtered
          .where(
            (wine) => wine.location != null &&
                filter.locations.contains(wine.location),
          )
          .toList();
    }

    if (sort != null) {
      filtered = sort.apply(filtered);
    }

    return filtered;
  }

  static String colorFilterLabel(WineColor color) {
    return '${color.emoji} ${color.label}';
  }

  static String maturityFilterLabel(WineMaturity maturity) {
    return '${maturity.emoji} ${maturity.label}';
  }

  static bool shouldShowLocationClearAction(Set<String> locations) {
    return locations.isNotEmpty;
  }
}