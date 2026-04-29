import 'package:wine_cellar/features/ai_assistant/domain/entities/chat_message.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine_from_image.dart';

enum ChatImageCapturePlanType {
  noop,
  requireVisionConfiguration,
  proceedWithOcr,
  proceedWithVision,
}

class ChatImageCapturePlan {
  final ChatImageCapturePlanType type;

  const ChatImageCapturePlan(this.type);
}

class ChatImageAnalysisHelper {
  ChatImageAnalysisHelper._();

  static ChatImageCapturePlan planCapture({
    required bool isLoading,
    required bool useOcr,
    required bool hasVisionUseCase,
  }) {
    if (isLoading) {
      return const ChatImageCapturePlan(ChatImageCapturePlanType.noop);
    }
    if (!useOcr && !hasVisionUseCase) {
      return const ChatImageCapturePlan(
        ChatImageCapturePlanType.requireVisionConfiguration,
      );
    }
    return ChatImageCapturePlan(
      useOcr
          ? ChatImageCapturePlanType.proceedWithOcr
          : ChatImageCapturePlanType.proceedWithVision,
    );
  }

  static List<Map<String, String>> buildConversationHistory(
    List<ChatMessage> messages,
  ) {
    return messages
        .where((message) => message.role != ChatRole.system)
        .map(
          (message) => {
            'role': message.role == ChatRole.user ? 'user' : 'assistant',
            'content': message.content,
          },
        )
        .toList();
  }

  static AnalyzeWineFromImageParams buildVisionParams({
    required List<int> imageBytes,
    required String mimeType,
    required String userMessage,
    required List<ChatMessage> messages,
  }) {
    return AnalyzeWineFromImageParams(
      imageBytes: imageBytes,
      mimeType: mimeType,
      userMessage: userMessage,
      conversationHistory: buildConversationHistory(messages),
    );
  }
}