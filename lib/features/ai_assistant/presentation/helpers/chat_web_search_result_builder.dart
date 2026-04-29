import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_response_enricher.dart';

class ChatWebSearchResultBuilder {
  ChatWebSearchResultBuilder._();

  static ChatMessage buildAssistantMessage({
    required String messageId,
    required DateTime timestamp,
    required AiChatResult result,
  }) {
    final chatSources = ChatResponseEnricher.chatSourcesFromWebSources(
      result.webSources,
    );

    return ChatMessage(
      id: messageId,
      content: result.textResponse,
      role: ChatRole.assistant,
      timestamp: timestamp,
      webSources: chatSources,
      collapseSourcesByDefault: chatSources.isNotEmpty,
    );
  }
}