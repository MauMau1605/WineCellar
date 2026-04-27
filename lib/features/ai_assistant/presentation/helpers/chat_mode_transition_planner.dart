import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';

enum ChatConversationMode { addWine, foodPairing, wineReview }

class ChatModeTransitionPlan {
  final int pendingAddWineCount;
  final bool requiresPendingConfirmation;
  final String activationMessage;

  const ChatModeTransitionPlan({
    required this.pendingAddWineCount,
    required this.requiresPendingConfirmation,
    required this.activationMessage,
  });
}

class ChatConversationResetState {
  final ChatConversationMode mode;
  final List<ChatMessage> messages;
  final List<WineAiResponse> wineDataList;
  final Set<int> addedWineIndices;

  const ChatConversationResetState({
    required this.mode,
    required this.messages,
    required this.wineDataList,
    required this.addedWineIndices,
  });
}

class ChatModeTransitionPlanner {
  ChatModeTransitionPlanner._();

  static int countPendingAddWines({
    required List<WineAiResponse> wines,
    required Set<int> addedIndices,
  }) {
    var pendingCount = 0;
    for (var i = 0; i < wines.length; i++) {
      if (!addedIndices.contains(i) && wines[i].name != null) {
        pendingCount++;
      }
    }
    return pendingCount;
  }

  static ChatModeTransitionPlan buildModeTransitionPlan({
    required ChatConversationMode currentMode,
    required ChatConversationMode newMode,
    required List<WineAiResponse> wines,
    required Set<int> addedIndices,
    required bool hasWebSearch,
  }) {
    final pendingCount = countPendingAddWines(
      wines: wines,
      addedIndices: addedIndices,
    );

    return ChatModeTransitionPlan(
      pendingAddWineCount: pendingCount,
      requiresPendingConfirmation:
          currentMode == ChatConversationMode.addWine &&
          newMode != ChatConversationMode.addWine &&
          pendingCount > 0,
      activationMessage: buildActivationMessage(
        mode: newMode,
        hasWebSearch: hasWebSearch,
      ),
    );
  }

  static String buildActivationMessage({
    required ChatConversationMode mode,
    required bool hasWebSearch,
  }) {
    switch (mode) {
      case ChatConversationMode.foodPairing:
        return '🔍 **Mode accord mets-vin activé**\n'
            'Décrivez votre repas et je chercherai le meilleur vin '
            'dans votre cave. Les vins à boire prochainement seront '
            'privilégiés.\n\n'
            'Exemples :\n'
            '• "Je prépare un gigot d\'agneau"\n'
            '• "Plateau de fromages ce soir"\n'
            '• "Sushi et cuisine japonaise"';
      case ChatConversationMode.wineReview:
        if (hasWebSearch) {
          return '📋 **Mode avis sur un vin activé**\n'
              'Demandez-moi des informations sur un vin et je '
              'chercherai des avis et notes sur internet via '
              'Google Search.\n\n'
              '🌐 Les sources seront citées pour chaque information.\n\n'
              'Exemples :\n'
              '• "Que vaut le Château Margaux 2015 ?"\n'
              '• "Parle-moi du Domaine de la Romanée-Conti"\n'
              '• "Le millésime 2020 en Bourgogne est-il bon ?"';
        }
        return '📋 **Mode avis sur un vin activé**\n'
            'Demandez-moi des informations sur un vin et je vous '
            'donnerai ce que je sais avec honnêteté — en distinguant '
            'les faits établis de mes estimations.\n\n'
            '⚠️ La recherche web n\'est disponible qu\'avec Gemini. '
            'Ajoutez une clé API Gemini dans les paramètres pour '
            'activer la recherche internet.\n\n'
            'Exemples :\n'
            '• "Que vaut le Château Margaux 2015 ?"\n'
            '• "Parle-moi du Domaine de la Romanée-Conti"\n'
            '• "Le millésime 2020 en Bourgogne est-il bon ?"';
      case ChatConversationMode.addWine:
        return '🍷 **Mode ajout de vin activé**\n'
            'Décrivez-moi les vins que vous souhaitez ajouter à '
            'votre cave.';
    }
  }

  static ChatMessage buildWelcomeMessage({
    required String messageId,
    required DateTime timestamp,
  }) {
    return ChatMessage(
      id: messageId,
      content: 'Bonjour ! 🍷 Décrivez-moi le ou les vins que vous souhaitez ajouter à votre cave.\n\n'
          'Par exemple :\n'
          '• "J\'ai acheté un Château Margaux 2015, rouge, 3 bouteilles à 45€"\n'
          '• "Un Chablis Premier Cru 2020"\n'
          '• "Côtes du Rhône rouge 2019, Guigal"\n'
          '• "3 vins : Sancerre 2022, Pouilly-Fumé 2021 et Vouvray 2020"',
      role: ChatRole.assistant,
      timestamp: timestamp,
    );
  }

  static ChatConversationResetState buildResetState({
    required String welcomeMessageId,
    required DateTime timestamp,
  }) {
    return ChatConversationResetState(
      mode: ChatConversationMode.addWine,
      messages: [
        buildWelcomeMessage(messageId: welcomeMessageId, timestamp: timestamp),
      ],
      wineDataList: const [],
      addedWineIndices: const <int>{},
    );
  }
}