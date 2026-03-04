import 'package:wine_cellar/core/enums.dart';

/// Filter criteria for wine searches
class WineFilter {
  final String? searchQuery;
  final WineColor? color;
  final int? foodCategoryId;
  final WineMaturity? maturity;

  const WineFilter({
    this.searchQuery,
    this.color,
    this.foodCategoryId,
    this.maturity,
  });

  bool get isEmpty =>
      searchQuery == null &&
      color == null &&
      foodCategoryId == null &&
      maturity == null;

  WineFilter copyWith({
    String? searchQuery,
    WineColor? color,
    int? foodCategoryId,
    WineMaturity? maturity,
    bool clearSearch = false,
    bool clearColor = false,
    bool clearFoodCategory = false,
    bool clearMaturity = false,
  }) {
    return WineFilter(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      color: clearColor ? null : (color ?? this.color),
      foodCategoryId:
          clearFoodCategory ? null : (foodCategoryId ?? this.foodCategoryId),
      maturity: clearMaturity ? null : (maturity ?? this.maturity),
    );
  }
}
