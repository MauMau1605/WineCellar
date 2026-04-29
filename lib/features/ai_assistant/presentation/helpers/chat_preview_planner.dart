import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';

class ChatPreviewCardPlan {
  final bool alreadyAdded;
  final bool canConfirm;
  final bool canEdit;
  final bool canForceAdd;

  const ChatPreviewCardPlan({
    required this.alreadyAdded,
    required this.canConfirm,
    required this.canEdit,
    required this.canForceAdd,
  });
}

class ChatPreviewSectionPlan {
  final bool showAddAllButton;
  final int remainingCompleteCount;
  final List<ChatPreviewCardPlan> cardPlans;

  const ChatPreviewSectionPlan({
    required this.showAddAllButton,
    required this.remainingCompleteCount,
    required this.cardPlans,
  });
}

class ChatPreviewPlanner {
  ChatPreviewPlanner._();

  static ChatPreviewSectionPlan build({
    required List<WineAiResponse> wines,
    required Set<int> addedIndices,
  }) {
    final completeWines = wines.where((wine) => wine.isComplete).length;
    final remainingCompleteCount = completeWines - addedIndices.length;

    final cardPlans = <ChatPreviewCardPlan>[];
    for (var i = 0; i < wines.length; i++) {
      final alreadyAdded = addedIndices.contains(i);
      final wineData = wines[i];
      cardPlans.add(
        ChatPreviewCardPlan(
          alreadyAdded: alreadyAdded,
          canConfirm: !alreadyAdded,
          canEdit: !alreadyAdded,
          canForceAdd: !alreadyAdded && !wineData.isComplete,
        ),
      );
    }

    return ChatPreviewSectionPlan(
      showAddAllButton:
          wines.length > 1 && completeWines > 0 && remainingCompleteCount > 0,
      remainingCompleteCount: remainingCompleteCount < 0
          ? 0
          : remainingCompleteCount,
      cardPlans: cardPlans,
    );
  }
}