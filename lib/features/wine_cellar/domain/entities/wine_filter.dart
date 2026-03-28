import 'package:wine_cellar/core/enums.dart';

/// Filter criteria for wine searches
class WineFilter {
  final String? searchQuery;
  final WineColor? color;
  final int? foodCategoryId;
  final WineMaturity? maturity;
  final Set<String> locations;

  const WineFilter({
    this.searchQuery,
    this.color,
    this.foodCategoryId,
    this.maturity,
    this.locations = const {},
  });

  bool get isEmpty =>
      searchQuery == null &&
      color == null &&
      foodCategoryId == null &&
      maturity == null &&
      locations.isEmpty;

  WineFilter copyWith({
    String? searchQuery,
    WineColor? color,
    int? foodCategoryId,
    WineMaturity? maturity,
    Set<String>? locations,
    bool clearSearch = false,
    bool clearColor = false,
    bool clearFoodCategory = false,
    bool clearMaturity = false,
    bool clearLocations = false,
  }) {
    return WineFilter(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      color: clearColor ? null : (color ?? this.color),
      foodCategoryId:
          clearFoodCategory ? null : (foodCategoryId ?? this.foodCategoryId),
      maturity: clearMaturity ? null : (maturity ?? this.maturity),
      locations: clearLocations ? const {} : (locations ?? this.locations),
    );
  }
}
