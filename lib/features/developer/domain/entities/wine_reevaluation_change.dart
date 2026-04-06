import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Result of an AI re-evaluation for a single wine.
class WineReevaluationChange {
  final WineEntity originalWine;

  /// True when the AI found no changes worth applying.
  final bool unchanged;

  /// True when an AI error occurred for this wine.
  final bool hasError;
  final String? errorMessage;

  // Updated drinking window (null = not evaluated or genuinely unchanged)
  final int? newDrinkFromYear;
  final int? newDrinkUntilYear;

  // Updated food pairings (null = not evaluated)
  final List<int>? newFoodCategoryIds;

  /// Human-readable names of new food pairings (for display, not persisted).
  final List<String>? newFoodPairingNames;

  const WineReevaluationChange({
    required this.originalWine,
    this.unchanged = false,
    this.hasError = false,
    this.errorMessage,
    this.newDrinkFromYear,
    this.newDrinkUntilYear,
    this.newFoodCategoryIds,
    this.newFoodPairingNames,
  });

  factory WineReevaluationChange.unchanged(WineEntity wine) =>
      WineReevaluationChange(originalWine: wine, unchanged: true);

  factory WineReevaluationChange.error(WineEntity wine, String message) =>
      WineReevaluationChange(
        originalWine: wine,
        hasError: true,
        errorMessage: message,
      );

  bool get hasDrinkingWindowChange =>
      (newDrinkFromYear != null &&
          newDrinkFromYear != originalWine.drinkFromYear) ||
      (newDrinkUntilYear != null &&
          newDrinkUntilYear != originalWine.drinkUntilYear);

  bool get hasFoodPairingsChange {
    if (newFoodCategoryIds == null) return false;
    final oldSet = originalWine.foodCategoryIds.toSet();
    final newSet = newFoodCategoryIds!.toSet();
    return oldSet != newSet;
  }

  bool get hasAnyChange => hasDrinkingWindowChange || hasFoodPairingsChange;
}
