import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

class ChatWineDraftBuilder {
  ChatWineDraftBuilder._();

  static List<int> matchFoodPairingCategoryIds({
    required List<String> pairingNames,
    required List<FoodCategoryEntity> allCategories,
  }) {
    final matchedCategoryIds = <int>[];
    for (final pairingName in pairingNames) {
      final loweredPairing = pairingName.toLowerCase();
      final match = allCategories.where(
        (category) =>
            category.name.toLowerCase().contains(loweredPairing) ||
            loweredPairing.contains(category.name.toLowerCase()),
      );
      if (match.isNotEmpty) {
        matchedCategoryIds.add(match.first.id);
      }
    }
    return matchedCategoryIds;
  }

  static WineEntity buildPersistableWine({
    required WineAiResponse data,
    required List<FoodCategoryEntity> allCategories,
    required bool manuallyEdited,
  }) {
    final matchedCategoryIds = matchFoodPairingCategoryIds(
      pairingNames: data.suggestedFoodPairings,
      allCategories: allCategories,
    );

    final rawQuantity = data.quantity ?? 1;
    final safeQuantity = rawQuantity <= 0 ? 1 : rawQuantity;

    return WineEntity(
      name: data.name!,
      appellation: data.appellation,
      producer: data.producer,
      region: data.region,
      country: data.country ?? 'France',
      color: WineColor.values.firstWhere(
        (color) => color.name == data.color,
        orElse: () => WineColor.red,
      ),
      vintage: data.vintage,
      grapeVarieties: data.grapeVarieties,
      quantity: safeQuantity,
      purchasePrice: data.purchasePrice,
      drinkFromYear: data.drinkFromYear,
      aiSuggestedDrinkFromYear: !manuallyEdited && data.drinkFromYear != null,
      drinkUntilYear: data.drinkUntilYear,
      aiSuggestedDrinkUntilYear:
          !manuallyEdited && data.drinkUntilYear != null,
      tastingNotes: data.tastingNotes,
      aiDescription: data.description,
      aiSuggestedFoodPairings:
          !manuallyEdited && matchedCategoryIds.isNotEmpty,
      foodCategoryIds: matchedCategoryIds,
    );
  }
}