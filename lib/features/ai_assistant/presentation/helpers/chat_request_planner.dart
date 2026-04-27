import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';

enum ChatRequestMode { addWine, foodPairing, wineReview }

class ChatRequestPlan {
  final String messageToSend;
  final bool useWebSearchForReview;
  final bool useFallbackWebSearchDirectCall;

  const ChatRequestPlan({
    required this.messageToSend,
    required this.useWebSearchForReview,
    required this.useFallbackWebSearchDirectCall,
  });
}

class ChatRequestPlanner {
  ChatRequestPlanner._();

  static ChatRequestPlan build({
    required ChatRequestMode mode,
    required String userMessage,
    String? aiMessageOverride,
    AddWineMessageIntent? addWineIntent,
    String currentWineSummary = '',
    String cellarSummary = '',
    required bool mainServiceSupportsWebSearch,
    required bool hasFallbackWebSearch,
  }) {
    final trimmedUserMessage = userMessage.trim();
    final trimmedOverride = aiMessageOverride?.trim();
    final hasAiOverride = trimmedOverride != null && trimmedOverride.isNotEmpty;

    var messageToSend = hasAiOverride ? trimmedOverride! : trimmedUserMessage;

    if (!hasAiOverride) {
      switch (mode) {
        case ChatRequestMode.foodPairing:
          messageToSend = AiPrompts.buildCellarSearchMessage(
            userQuestion: trimmedUserMessage,
            cellarSummary: cellarSummary,
          );
          break;
        case ChatRequestMode.wineReview:
          messageToSend =
              mainServiceSupportsWebSearch || hasFallbackWebSearch
              ? AiPrompts.buildGroundedReviewMessage(
                  userQuestion: trimmedUserMessage,
                )
              : AiPrompts.buildWineReviewMessage(
                  userQuestion: trimmedUserMessage,
                );
          break;
        case ChatRequestMode.addWine:
          if (addWineIntent == AddWineMessageIntent.newWine) {
            messageToSend = AiPrompts.buildNewWineStandaloneMessage(
              userMessage: trimmedUserMessage,
            );
          } else if (addWineIntent == AddWineMessageIntent.refineCurrentWine) {
            messageToSend = AiPrompts.buildCurrentWineRefinementMessage(
              userMessage: trimmedUserMessage,
              currentWineSummary: currentWineSummary,
            );
          }
          break;
      }
    }

    final useWebSearchForReview =
        mode == ChatRequestMode.wineReview &&
        (mainServiceSupportsWebSearch || hasFallbackWebSearch);

    final useFallbackWebSearchDirectCall =
        mode == ChatRequestMode.wineReview &&
        !mainServiceSupportsWebSearch &&
        hasFallbackWebSearch;

    return ChatRequestPlan(
      messageToSend: messageToSend,
      useWebSearchForReview: useWebSearchForReview,
      useFallbackWebSearchDirectCall: useFallbackWebSearchDirectCall,
    );
  }
}