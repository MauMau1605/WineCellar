import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_mode_transition_planner.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_prefill_helper.dart';

void main() {
  group('ChatPrefillHelper.buildPlan', () {
    test('bascule vers le mode ajout et envoie le prompt si l IA est disponible', () {
      final plan = ChatPrefillHelper.buildPlan(
        currentMode: ChatConversationMode.foodPairing,
        hasAnalyzeUseCase: true,
        displayText: 'Champ 1: Chablis',
        aiPrompt: 'Prompt complet',
      );

      expect(plan.shouldSwitchToAddWineMode, isTrue);
      expect(plan.actionType, ChatPrefillActionType.sendPrompt);
      expect(plan.displayText, 'Champ 1: Chablis');
      expect(plan.aiPrompt, 'Prompt complet');
    });

    test('ne rebascule pas si le chat est deja en mode ajout', () {
      final plan = ChatPrefillHelper.buildPlan(
        currentMode: ChatConversationMode.addWine,
        hasAnalyzeUseCase: true,
        displayText: 'Champ 1: Chablis',
        aiPrompt: 'Prompt complet',
      );

      expect(plan.shouldSwitchToAddWineMode, isFalse);
      expect(plan.actionType, ChatPrefillActionType.sendPrompt);
    });

    test('remplit seulement le champ texte si l IA nest pas configuree', () {
      final plan = ChatPrefillHelper.buildPlan(
        currentMode: ChatConversationMode.wineReview,
        hasAnalyzeUseCase: false,
        displayText: 'Champ 1: Chablis',
        aiPrompt: 'Prompt complet',
      );

      expect(plan.shouldSwitchToAddWineMode, isTrue);
      expect(plan.actionType, ChatPrefillActionType.fillTextOnly);
      expect(plan.displayText, 'Champ 1: Chablis');
      expect(plan.aiPrompt, isNull);
    });
  });
}