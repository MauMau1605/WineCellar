import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_request_planner.dart';

void main() {
  group('ChatRequestPlanner', () {
    test('conserve un override IA explicite', () {
      final plan = ChatRequestPlanner.build(
        mode: ChatRequestMode.addWine,
        userMessage: 'Message visible',
        aiMessageOverride: 'Prompt IA prioritaire',
        addWineIntent: AddWineMessageIntent.newWine,
        mainServiceSupportsWebSearch: false,
        hasFallbackWebSearch: false,
      );

      expect(plan.messageToSend, 'Prompt IA prioritaire');
      expect(plan.useWebSearchForReview, isFalse);
      expect(plan.useFallbackWebSearchDirectCall, isFalse);
    });

    test('compose un message de recherche cave en mode food pairing', () {
      final plan = ChatRequestPlanner.build(
        mode: ChatRequestMode.foodPairing,
        userMessage: 'Que servir avec ce plat ?',
        cellarSummary: '2 vins disponibles',
        mainServiceSupportsWebSearch: false,
        hasFallbackWebSearch: false,
      );

      expect(
        plan.messageToSend,
        AiPrompts.buildCellarSearchMessage(
          userQuestion: 'Que servir avec ce plat ?',
          cellarSummary: '2 vins disponibles',
        ),
      );
      expect(plan.useWebSearchForReview, isFalse);
    });

    test('utilise le prompt grounded review si le service principal supporte le web', () {
      final plan = ChatRequestPlanner.build(
        mode: ChatRequestMode.wineReview,
        userMessage: 'Que vaut ce vin ?',
        mainServiceSupportsWebSearch: true,
        hasFallbackWebSearch: false,
      );

      expect(
        plan.messageToSend,
        AiPrompts.buildGroundedReviewMessage(
          userQuestion: 'Que vaut ce vin ?',
        ),
      );
      expect(plan.useWebSearchForReview, isTrue);
      expect(plan.useFallbackWebSearchDirectCall, isFalse);
    });

    test('active le fallback web direct si seul Gemini fallback est disponible', () {
      final plan = ChatRequestPlanner.build(
        mode: ChatRequestMode.wineReview,
        userMessage: 'Que vaut ce vin ?',
        mainServiceSupportsWebSearch: false,
        hasFallbackWebSearch: true,
      );

      expect(
        plan.messageToSend,
        AiPrompts.buildGroundedReviewMessage(
          userQuestion: 'Que vaut ce vin ?',
        ),
      );
      expect(plan.useWebSearchForReview, isTrue);
      expect(plan.useFallbackWebSearchDirectCall, isTrue);
    });

    test('revient au prompt review standard sans acces web', () {
      final plan = ChatRequestPlanner.build(
        mode: ChatRequestMode.wineReview,
        userMessage: 'Que vaut ce vin ?',
        mainServiceSupportsWebSearch: false,
        hasFallbackWebSearch: false,
      );

      expect(
        plan.messageToSend,
        AiPrompts.buildWineReviewMessage(
          userQuestion: 'Que vaut ce vin ?',
        ),
      );
      expect(plan.useWebSearchForReview, isFalse);
      expect(plan.useFallbackWebSearchDirectCall, isFalse);
    });

    test('compose un prompt standalone pour un nouveau vin', () {
      final plan = ChatRequestPlanner.build(
        mode: ChatRequestMode.addWine,
        userMessage: 'J ai achete un Chablis 2022',
        addWineIntent: AddWineMessageIntent.newWine,
        mainServiceSupportsWebSearch: false,
        hasFallbackWebSearch: false,
      );

      expect(
        plan.messageToSend,
        AiPrompts.buildNewWineStandaloneMessage(
          userMessage: 'J ai achete un Chablis 2022',
        ),
      );
    });

    test('compose un prompt de refinement pour le vin courant', () {
      final plan = ChatRequestPlanner.build(
        mode: ChatRequestMode.addWine,
        userMessage: 'En fait le millesime est 2019',
        addWineIntent: AddWineMessageIntent.refineCurrentWine,
        currentWineSummary: 'Nom: Chablis | Millésime: 2020',
        mainServiceSupportsWebSearch: false,
        hasFallbackWebSearch: false,
      );

      expect(
        plan.messageToSend,
        AiPrompts.buildCurrentWineRefinementMessage(
          userMessage: 'En fait le millesime est 2019',
          currentWineSummary: 'Nom: Chablis | Millésime: 2020',
        ),
      );
    });
  });
}