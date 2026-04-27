import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_mode_transition_planner.dart';

void main() {
  group('ChatModeTransitionPlanner.countPendingAddWines', () {
    test('compte seulement les fiches nommees non ajoutees', () {
      final count = ChatModeTransitionPlanner.countPendingAddWines(
        wines: const [
          WineAiResponse(name: 'Chablis', color: 'white'),
          WineAiResponse(color: 'red'),
          WineAiResponse(name: 'Margaux', color: 'red'),
        ],
        addedIndices: const {2},
      );

      expect(count, 1);
    });
  });

  group('ChatModeTransitionPlanner.buildModeTransitionPlan', () {
    test('demande confirmation en quittant le mode ajout avec fiches en attente', () {
      final plan = ChatModeTransitionPlanner.buildModeTransitionPlan(
        currentMode: ChatConversationMode.addWine,
        newMode: ChatConversationMode.foodPairing,
        wines: const [WineAiResponse(name: 'Chablis', color: 'white')],
        addedIndices: const {},
        hasWebSearch: false,
      );

      expect(plan.requiresPendingConfirmation, isTrue);
      expect(plan.pendingAddWineCount, 1);
      expect(plan.activationMessage, contains('Mode accord mets-vin activé'));
    });

    test('ne demande pas confirmation sans fiche en attente', () {
      final plan = ChatModeTransitionPlanner.buildModeTransitionPlan(
        currentMode: ChatConversationMode.addWine,
        newMode: ChatConversationMode.foodPairing,
        wines: const [WineAiResponse(name: 'Chablis', color: 'white')],
        addedIndices: const {0},
        hasWebSearch: false,
      );

      expect(plan.requiresPendingConfirmation, isFalse);
      expect(plan.pendingAddWineCount, 0);
    });

    test('construit le message avis avec web search', () {
      final plan = ChatModeTransitionPlanner.buildModeTransitionPlan(
        currentMode: ChatConversationMode.addWine,
        newMode: ChatConversationMode.wineReview,
        wines: const [],
        addedIndices: const {},
        hasWebSearch: true,
      );

      expect(plan.activationMessage, contains('Google Search'));
      expect(plan.activationMessage, contains('Les sources seront citées'));
    });

    test('construit le message avis sans web search', () {
      final plan = ChatModeTransitionPlanner.buildModeTransitionPlan(
        currentMode: ChatConversationMode.foodPairing,
        newMode: ChatConversationMode.wineReview,
        wines: const [],
        addedIndices: const {},
        hasWebSearch: false,
      );

      expect(plan.activationMessage, contains('La recherche web n\'est disponible qu\'avec Gemini'));
      expect(plan.activationMessage, isNot(contains('Les sources seront citées')));
    });

    test('construit le message mode ajout', () {
      final plan = ChatModeTransitionPlanner.buildModeTransitionPlan(
        currentMode: ChatConversationMode.foodPairing,
        newMode: ChatConversationMode.addWine,
        wines: const [],
        addedIndices: const {},
        hasWebSearch: false,
      );

      expect(plan.activationMessage, contains('Mode ajout de vin activé'));
    });
  });

  group('ChatModeTransitionPlanner.buildWelcomeMessage', () {
    test('construit le message de bienvenue attendu', () {
      final message = ChatModeTransitionPlanner.buildWelcomeMessage(
        messageId: 'welcome',
        timestamp: DateTime(2026),
      );

      expect(message.id, 'welcome');
      expect(message.role, ChatRole.assistant);
      expect(message.content, contains('Décrivez-moi le ou les vins'));
      expect(message.content, contains('Château Margaux 2015'));
    });
  });

  group('ChatModeTransitionPlanner.buildResetState', () {
    test('reinitialise la conversation en mode ajout avec un seul message de bienvenue', () {
      final state = ChatModeTransitionPlanner.buildResetState(
        welcomeMessageId: 'reset',
        timestamp: DateTime(2026),
      );

      expect(state.mode, ChatConversationMode.addWine);
      expect(state.messages, hasLength(1));
      expect(state.messages.first.id, 'reset');
      expect(state.messages.first.role, ChatRole.assistant);
      expect(state.wineDataList, isEmpty);
      expect(state.addedWineIndices, isEmpty);
    });
  });
}