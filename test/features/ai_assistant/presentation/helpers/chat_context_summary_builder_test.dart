import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_context_summary_builder.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

void main() {
  group('ChatContextSummaryBuilder.buildCellarSummary', () {
    test('retourne un message cave vide si aucune bouteille n est disponible', () {
      final result = ChatContextSummaryBuilder.buildCellarSummary([
        const WineEntity(name: 'Vide', color: WineColor.red, quantity: 0),
      ]);

      expect(result, '(Cave vide — aucune bouteille disponible)');
    });

    test('filtre les vins sans stock et trie par drinkUntilYear croissant', () {
      final result = ChatContextSummaryBuilder.buildCellarSummary([
        const WineEntity(
          name: 'Vin tardif',
          color: WineColor.red,
          quantity: 1,
          drinkUntilYear: 2035,
        ),
        const WineEntity(
          name: 'Vin prioritaire',
          color: WineColor.white,
          quantity: 2,
          drinkFromYear: 2024,
          drinkUntilYear: 2028,
          grapeVarieties: ['Chardonnay'],
          tastingNotes: 'A ouvrir bientot',
        ),
        const WineEntity(
          name: 'Sans stock',
          color: WineColor.rose,
          quantity: 0,
          drinkUntilYear: 2026,
        ),
      ]);

      expect(result, contains('2 vin(s) disponible(s)'));
      expect(result, isNot(contains('Sans stock')));

      final priorityIndex = result.indexOf('Vin prioritaire');
      final lateIndex = result.indexOf('Vin tardif');
      expect(priorityIndex, isNonNegative);
      expect(lateIndex, isNonNegative);
      expect(priorityIndex, lessThan(lateIndex));
      expect(result, contains('Cépages : Chardonnay'));
      expect(result, contains('Notes : A ouvrir bientot'));
      expect(result, contains('À boire : 2024 → 2028'));
    });
  });

  group('ChatContextSummaryBuilder.buildCurrentWineSummaryForRefinement', () {
    test('retourne une indication vide si aucune fiche n est active', () {
      final result =
          ChatContextSummaryBuilder.buildCurrentWineSummaryForRefinement(
            const [],
          );

      expect(result, 'Aucune fiche active.');
    });

    test('retourne une indication incomplete si aucun champ utile n est present', () {
      final result =
          ChatContextSummaryBuilder.buildCurrentWineSummaryForRefinement(
            const [WineAiResponse()],
          );

      expect(result, 'Une fiche vin est en cours mais encore incomplète.');
    });

    test('assemble les champs utiles du premier vin courant', () {
      final result =
          ChatContextSummaryBuilder.buildCurrentWineSummaryForRefinement(
            const [
              WineAiResponse(
                name: 'Chablis',
                vintage: 2020,
                appellation: 'Chablis Premier Cru',
                producer: 'Domaine Test',
              ),
            ],
          );

      expect(
        result,
        'Nom: Chablis | Millésime: 2020 | Appellation: Chablis Premier Cru | Producteur: Domaine Test',
      );
    });
  });
}