import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_completion_parser.dart';

enum ChatWebCompletionResultType {
  noComplementFound,
  noFieldsConfirmed,
  success,
}

class ChatWebCompletionResult {
  final ChatWebCompletionResultType type;
  final String assistantMessage;
  final WineAiResponse? mergedWine;
  final List<String> completedFields;

  const ChatWebCompletionResult({
    required this.type,
    required this.assistantMessage,
    this.mergedWine,
    this.completedFields = const [],
  });

  bool get isSuccess => type == ChatWebCompletionResultType.success;
}

class ChatWebCompletionResolver {
  ChatWebCompletionResolver._();

  static ChatWebCompletionResult resolve({
    required WineAiResponse wine,
    required String responseText,
    required bool triggeredAutomatically,
  }) {
    final complementData = ChatCompletionParser.extractCompletionJson(
      responseText,
    );

    if (complementData == null) {
      return ChatWebCompletionResult(
        type: ChatWebCompletionResultType.noComplementFound,
        assistantMessage:
            '⚠️ Aucune information complémentaire trouvée dans les résultats '
            'de recherche.\n\n$responseText',
      );
    }

    final complement = WineAiResponse.fromJson(complementData);
    final completedFields = wine.estimatedFields
        .where((field) => WineAiResponse.fieldWasCompleted(field, complement))
        .toList();

    if (completedFields.isEmpty) {
      return ChatWebCompletionResult(
        type: ChatWebCompletionResultType.noFieldsConfirmed,
        assistantMessage:
            '⚠️ La recherche n\'a pas permis de confirmer les informations '
            'estimées.\n\n$responseText',
      );
    }

    return ChatWebCompletionResult(
      type: ChatWebCompletionResultType.success,
      mergedWine: wine.mergeWith(complement),
      completedFields: completedFields,
      assistantMessage: triggeredAutomatically
          ? '✅ **${completedFields.length} champ(s) auto-complété(s)** '
              'via la recherche internet :\n'
              '${completedFields.map((field) => '• $field').join('\n')}'
          : '✅ **${completedFields.length} champ(s) complété(s)** '
              'via la recherche Google :\n'
              '${completedFields.map((field) => '• $field').join('\n')}',
    );
  }
}