import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_preview_planner.dart';

void main() {
  group('ChatPreviewPlanner.build', () {
    test('affiche le bouton ajouter tout seulement pour plusieurs vins complets restants', () {
      final plan = ChatPreviewPlanner.build(
        wines: const [
          WineAiResponse(name: 'Chablis', color: 'white'),
          WineAiResponse(name: 'Margaux', color: 'red'),
        ],
        addedIndices: const {1},
      );

      expect(plan.showAddAllButton, isTrue);
      expect(plan.remainingCompleteCount, 1);
    });

    test('masque le bouton ajouter tout si aucun vin complet restant', () {
      final plan = ChatPreviewPlanner.build(
        wines: const [
          WineAiResponse(name: 'Chablis', color: 'white'),
          WineAiResponse(name: 'Margaux', color: 'red'),
        ],
        addedIndices: const {0, 1},
      );

      expect(plan.showAddAllButton, isFalse);
      expect(plan.remainingCompleteCount, 0);
    });

    test('calcule les actions de chaque carte', () {
      final plan = ChatPreviewPlanner.build(
        wines: const [
          WineAiResponse(name: 'Chablis', color: 'white'),
          WineAiResponse(name: 'Incomplet'),
        ],
        addedIndices: const {0},
      );

      expect(plan.cardPlans[0].alreadyAdded, isTrue);
      expect(plan.cardPlans[0].canConfirm, isFalse);
      expect(plan.cardPlans[0].canEdit, isFalse);
      expect(plan.cardPlans[0].canForceAdd, isFalse);

      expect(plan.cardPlans[1].alreadyAdded, isFalse);
      expect(plan.cardPlans[1].canConfirm, isTrue);
      expect(plan.cardPlans[1].canEdit, isTrue);
      expect(plan.cardPlans[1].canForceAdd, isTrue);
    });
  });
}