import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_add_intent_helper.dart';

void main() {
  group('ChatAddIntentHelper.resolve', () {
    test('retourne un nouveau vin directement si aucune fiche courante', () {
      final resolution = ChatAddIntentHelper.resolve(
        userMessage: 'Chablis 2020',
        currentWineData: const [],
      );

      expect(resolution.type, ChatAddIntentResolutionType.resolved);
      expect(resolution.intent, AddWineMessageIntent.newWine);
    });

    test('retourne une precision directe quand le message corrige le vin courant', () {
      final resolution = ChatAddIntentHelper.resolve(
        userMessage: 'en fait le millesime est 2021',
        currentWineData: const [WineAiResponse(name: 'Chablis', color: 'white')],
      );

      expect(resolution.type, ChatAddIntentResolutionType.resolved);
      expect(resolution.intent, AddWineMessageIntent.refineCurrentWine);
    });

    test('demande une clarification quand lintention reste ambigue', () {
      final resolution = ChatAddIntentHelper.resolve(
        userMessage: 'oui',
        currentWineData: const [WineAiResponse(name: 'Chablis', color: 'white')],
      );

      expect(
        resolution.type,
        ChatAddIntentResolutionType.needsClarification,
      );
      expect(resolution.intent, isNull);
    });
  });

  group('ChatAddIntentHelper dialog metadata', () {
    test('expose un titre et un message de clarification stables', () {
      expect(ChatAddIntentHelper.clarificationDialogTitle, isNotEmpty);
      expect(ChatAddIntentHelper.clarificationDialogMessage, contains('corriger le vin en cours'));
      expect(ChatAddIntentHelper.clarificationDialogMessage, contains('démarrer un nouveau vin'));
    });
  });
}