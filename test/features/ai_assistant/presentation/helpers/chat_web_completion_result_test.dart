import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_web_completion_result.dart';

void main() {
  group('ChatWebCompletionResolver', () {
    test('retourne noComplementFound si aucun JSON exploitable nest present', () {
      const wine = WineAiResponse(
        name: 'Chablis',
        estimatedFields: ['producer'],
      );

      final result = ChatWebCompletionResolver.resolve(
        wine: wine,
        responseText: 'Aucune donnee structurée disponible',
        triggeredAutomatically: true,
      );

      expect(result.type, ChatWebCompletionResultType.noComplementFound);
      expect(result.isSuccess, isFalse);
      expect(result.assistantMessage, contains('Aucune information complémentaire trouvée'));
      expect(result.mergedWine, isNull);
    });

    test('retourne noFieldsConfirmed si le JSON ne complete aucun champ estime', () {
      const wine = WineAiResponse(
        name: 'Chablis',
        estimatedFields: ['drinkFromYear', 'drinkUntilYear'],
      );

      final result = ChatWebCompletionResolver.resolve(
        wine: wine,
        responseText: '```json\n{"region":"Bourgogne"}\n```',
        triggeredAutomatically: false,
      );

      expect(result.type, ChatWebCompletionResultType.noFieldsConfirmed);
      expect(result.isSuccess, isFalse);
      expect(result.assistantMessage, contains('n\'a pas permis de confirmer'));
      expect(result.mergedWine, isNull);
    });

    test('retourne success, fusionne le vin et liste les champs completes', () {
      const wine = WineAiResponse(
        name: 'Chablis',
        estimatedFields: ['producer', 'drinkFromYear'],
      );

      final result = ChatWebCompletionResolver.resolve(
        wine: wine,
        responseText:
            '```json\n{"producer":"Domaine Test","drinkFromYear":2028}\n```',
        triggeredAutomatically: true,
      );

      expect(result.type, ChatWebCompletionResultType.success);
      expect(result.isSuccess, isTrue);
      expect(result.completedFields, ['producer', 'drinkFromYear']);
      expect(result.assistantMessage, contains('auto-complété(s)'));
      expect(result.assistantMessage, contains('• producer'));
      expect(result.assistantMessage, contains('• drinkFromYear'));
      expect(result.mergedWine, isNotNull);
      expect(result.mergedWine!.producer, 'Domaine Test');
      expect(result.mergedWine!.drinkFromYear, 2028);
      expect(result.mergedWine!.estimatedFields, isEmpty);
    });

    test('utilise le message manuel quand la completion nest pas automatique', () {
      const wine = WineAiResponse(
        name: 'Chablis',
        estimatedFields: ['producer'],
      );

      final result = ChatWebCompletionResolver.resolve(
        wine: wine,
        responseText: '```json\n{"producer":"Domaine Test"}\n```',
        triggeredAutomatically: false,
      );

      expect(result.type, ChatWebCompletionResultType.success);
      expect(result.assistantMessage, contains('complété(s)'));
      expect(result.assistantMessage, contains('recherche Google'));
      expect(result.assistantMessage, isNot(contains('auto-complété')));
    });
  });
}