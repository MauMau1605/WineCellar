import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_mode_transition_planner.dart';

enum ChatPrefillActionType { fillTextOnly, sendPrompt }

class ChatPrefillPlan {
  final bool shouldSwitchToAddWineMode;
  final ChatPrefillActionType actionType;
  final String displayText;
  final String? aiPrompt;

  const ChatPrefillPlan({
    required this.shouldSwitchToAddWineMode,
    required this.actionType,
    required this.displayText,
    this.aiPrompt,
  });
}

class ChatPrefillHelper {
  ChatPrefillHelper._();

  static ChatPrefillPlan buildPlan({
    required ChatConversationMode currentMode,
    required bool hasAnalyzeUseCase,
    required String displayText,
    required String aiPrompt,
  }) {
    return ChatPrefillPlan(
      shouldSwitchToAddWineMode: currentMode != ChatConversationMode.addWine,
      actionType: hasAnalyzeUseCase
          ? ChatPrefillActionType.sendPrompt
          : ChatPrefillActionType.fillTextOnly,
      displayText: displayText,
      aiPrompt: hasAnalyzeUseCase ? aiPrompt : null,
    );
  }
}