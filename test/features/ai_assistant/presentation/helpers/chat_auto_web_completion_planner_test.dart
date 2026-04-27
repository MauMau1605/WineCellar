import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_auto_web_completion_planner.dart';

void main() {
  group('ChatAutoWebCompletionPlanner.build', () {
    test('marque comme tentes les vins qui ne justifient pas une recherche web', () {
      final plan = ChatAutoWebCompletionPlanner.build(
        wines: const [
          WineAiResponse(
            name: 'Vin sans identite suffisante',
            estimatedFields: ['producer'],
          ),
        ],
        attemptedIndices: const {},
        addedIndices: const {},
        batchSize: 10,
      );

      expect(plan.indicesToMarkAttempted, [0]);
      expect(plan.completionBatches, isEmpty);
      expect(plan.hasWork, isFalse);
    });

    test('ignore les indices deja tentes, deja ajoutes ou sans donnees utiles', () {
      final plan = ChatAutoWebCompletionPlanner.build(
        wines: const [
          WineAiResponse(
            name: 'Deja tente',
            vintage: 2020,
            estimatedFields: ['producer'],
          ),
          WineAiResponse(
            name: 'Deja ajoute',
            vintage: 2020,
            estimatedFields: ['producer'],
          ),
          WineAiResponse(name: null, estimatedFields: ['producer']),
          WineAiResponse(name: 'Sans champ estime'),
        ],
        attemptedIndices: const {0},
        addedIndices: const {1},
        batchSize: 10,
      );

      expect(plan.indicesToMarkAttempted, isEmpty);
      expect(plan.completionBatches, isEmpty);
    });

    test('groupe les indices eligibles en lots de taille demandee', () {
      final wines = List.generate(
        5,
        (index) => WineAiResponse(
          name: 'Vin ${index + 1}',
          vintage: 2024,
          appellation: 'Appellation ${index + 1}',
          estimatedFields: const ['drinkFromYear'],
        ),
      );

      final plan = ChatAutoWebCompletionPlanner.build(
        wines: wines,
        attemptedIndices: const {},
        addedIndices: const {},
        batchSize: 2,
      );

      expect(plan.indicesToMarkAttempted, isEmpty);
      expect(plan.totalBatches, 3);
      expect(plan.completionBatches, const [
        [0, 1],
        [2, 3],
        [4],
      ]);
      expect(plan.hasWork, isTrue);
    });
  });

  group('ChatAutoWebCompletionPlanner.buildBatchProgressMessage', () {
    test('formate le message de progression de lot', () {
      final message = ChatAutoWebCompletionPlanner.buildBatchProgressMessage(
        batchNumber: 2,
        totalBatches: 3,
        batchSize: 4,
      );

      expect(message, '🌐 Complétion internet — lot 2/3 (4 vin(s))…');
    });
  });
}