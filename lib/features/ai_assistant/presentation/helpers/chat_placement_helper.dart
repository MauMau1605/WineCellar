typedef ChatAddedWineRecord = ({int id, String name});

enum ChatPlacementChoiceResolution { cancel, none, associateOnly, placeInSlot }

enum ChatSinglePlacementNextStepType { stop, chooseCellarOnly, navigateToSlot }

class ChatSinglePlacementNextStep {
  final ChatSinglePlacementNextStepType type;

  const ChatSinglePlacementNextStep(this.type);
}

class ChatPlacementHelper {
  ChatPlacementHelper._();

  static ChatSinglePlacementNextStep resolveSinglePlacement(
    ChatPlacementChoiceResolution choice,
  ) {
    switch (choice) {
      case ChatPlacementChoiceResolution.cancel:
      case ChatPlacementChoiceResolution.none:
        return const ChatSinglePlacementNextStep(
          ChatSinglePlacementNextStepType.stop,
        );
      case ChatPlacementChoiceResolution.associateOnly:
        return const ChatSinglePlacementNextStep(
          ChatSinglePlacementNextStepType.chooseCellarOnly,
        );
      case ChatPlacementChoiceResolution.placeInSlot:
        return const ChatSinglePlacementNextStep(
          ChatSinglePlacementNextStepType.navigateToSlot,
        );
    }
  }

  static bool shouldContinueGroupedPlacement(
    ChatPlacementChoiceResolution choice,
  ) {
    return choice == ChatPlacementChoiceResolution.associateOnly;
  }

  static String buildSinglePlacementRoute({
    required int cellarId,
    required int wineId,
  }) {
    return '/cellars/$cellarId?wineId=$wineId';
  }

  static String buildGroupedPlacementRoute({required int cellarId}) {
    return '/cellars/$cellarId';
  }

  static String buildGroupedPlacementSuccessMessage({
    required int wineCount,
    required String cellarName,
  }) {
    return '$wineCount vins associés à « $cellarName ».';
  }

  static String buildGroupedWineNames(List<ChatAddedWineRecord> wines) {
    return wines.map((wine) => '• ${wine.name}').join('\n');
  }
}