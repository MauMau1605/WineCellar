import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';

void main() {
  group('AiRequestStrategy.decideWebSearchForWineCompletion', () {
    test('active la recherche web pour des champs critiques avec identite suffisante', () {
      const wine = WineAiResponse(
        name: 'Chateau Test',
        vintage: 2019,
        estimatedFields: ['producer', 'drinkUntilYear'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isTrue);
    });

    test('active la recherche web pour 3+ champs estimés même si faible valeur', () {
      const wine = WineAiResponse(
        name: 'Sancerre Test',
        vintage: 2022,
        estimatedFields: ['country', 'region', 'grapeVarieties'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isTrue);
    });

    test('desactive la recherche web si moins de 3 champs estimés sans champ critique', () {
      const wine = WineAiResponse(
        name: 'Sancerre Test',
        vintage: 2022,
        estimatedFields: ['country', 'region'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isFalse);
    });

    test('desactive la recherche web sans signaux d identite', () {
      const wine = WineAiResponse(
        name: 'Vin inconnu',
        estimatedFields: ['producer', 'drinkFromYear'],
      );

      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wine);

      expect(decision.shouldUseWebSearch, isFalse);
    });
  });

  group('AiRequestStrategy.detectAddWineMessageIntent', () {
    test('retourne newWine quand aucune fiche en cours', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'J ai achete un Chablis 2020',
        currentWineData: const [],
      );

      expect(intent, AddWineMessageIntent.newWine);
    });

    test('retourne refineCurrentWine pour message de correction explicite', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'En fait le millesime est 2018',
        currentWineData: const [
          WineAiResponse(name: 'Cotes du Rhone', vintage: 2020),
        ],
      );

      expect(intent, AddWineMessageIntent.refineCurrentWine);
    });

    test('retourne newWine pour message explicite nouveau vin', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'Nouveau vin: Domaine X 2019',
        currentWineData: const [
          WineAiResponse(name: 'Premier vin', vintage: 2021),
        ],
      );

      expect(intent, AddWineMessageIntent.newWine);
    });

    test('retourne unclear pour message ambigu', () {
      final intent = AiRequestStrategy.detectAddWineMessageIntent(
        userMessage: 'ok merci',
        currentWineData: const [
          WineAiResponse(name: 'Premier vin', vintage: 2021),
        ],
      );

      expect(intent, AddWineMessageIntent.unclear);
    });
  });
}
