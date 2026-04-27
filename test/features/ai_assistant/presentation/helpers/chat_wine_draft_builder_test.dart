import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_wine_draft_builder.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';

void main() {
  const categories = [
    FoodCategoryEntity(id: 1, name: 'Viande rouge'),
    FoodCategoryEntity(id: 2, name: 'Poisson'),
    FoodCategoryEntity(id: 3, name: 'Fruits de mer'),
  ];

  group('ChatWineDraftBuilder.matchFoodPairingCategoryIds', () {
    test('associe les accords par correspondance partielle insensible a la casse', () {
      final result = ChatWineDraftBuilder.matchFoodPairingCategoryIds(
        pairingNames: ['poisson grille', 'FRUITS DE MER'],
        allCategories: categories,
      );

      expect(result, [2, 3]);
    });
  });

  group('ChatWineDraftBuilder.buildPersistableWine', () {
    test('construit un vin persistant avec les flags IA quand non edite manuellement', () {
      final wine = ChatWineDraftBuilder.buildPersistableWine(
        data: const WineAiResponse(
          name: 'Chablis',
          color: 'white',
          country: 'Italie',
          quantity: 3,
          drinkFromYear: 2026,
          drinkUntilYear: 2030,
          suggestedFoodPairings: ['Poisson'],
          description: 'Description IA',
        ),
        allCategories: categories,
        manuallyEdited: false,
      );

      expect(wine.name, 'Chablis');
      expect(wine.color, WineColor.white);
      expect(wine.country, 'Italie');
      expect(wine.quantity, 3);
      expect(wine.drinkFromYear, 2026);
      expect(wine.drinkUntilYear, 2030);
      expect(wine.aiSuggestedDrinkFromYear, isTrue);
      expect(wine.aiSuggestedDrinkUntilYear, isTrue);
      expect(wine.aiSuggestedFoodPairings, isTrue);
      expect(wine.foodCategoryIds, [2]);
      expect(wine.aiDescription, 'Description IA');
    });

    test('desactive les flags IA si la fiche a ete editee manuellement', () {
      final wine = ChatWineDraftBuilder.buildPersistableWine(
        data: const WineAiResponse(
          name: 'Chablis',
          color: 'white',
          drinkFromYear: 2026,
          drinkUntilYear: 2030,
          suggestedFoodPairings: ['Poisson'],
        ),
        allCategories: categories,
        manuallyEdited: true,
      );

      expect(wine.aiSuggestedDrinkFromYear, isFalse);
      expect(wine.aiSuggestedDrinkUntilYear, isFalse);
      expect(wine.aiSuggestedFoodPairings, isFalse);
      expect(wine.foodCategoryIds, [2]);
    });

    test('normalise la quantite invalide a 1', () {
      final wine = ChatWineDraftBuilder.buildPersistableWine(
        data: const WineAiResponse(
          name: 'Chablis',
          color: 'red',
          quantity: 0,
        ),
        allCategories: categories,
        manuallyEdited: false,
      );

      expect(wine.quantity, 1);
    });

    test('retombe sur rouge et France par defaut si les valeurs sont absentes ou inconnues', () {
      final wine = ChatWineDraftBuilder.buildPersistableWine(
        data: const WineAiResponse(
          name: 'Mystere',
          color: 'inconnue',
        ),
        allCategories: categories,
        manuallyEdited: false,
      );

      expect(wine.color, WineColor.red);
      expect(wine.country, 'France');
      expect(wine.quantity, 1);
    });
  });
}