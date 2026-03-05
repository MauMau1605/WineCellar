import '../entities/wine_ai_response.dart';

/// Abstract AI service interface - implementations for OpenAI, Ollama, etc.
/// This abstraction allows swapping AI providers without changing business logic.
abstract class AiService {
  /// Analyze a wine description and return structured data
  /// [userMessage] is the user's natural language description
  /// [conversationHistory] is the conversation so far for context
  Future<AiChatResult> analyzeWine({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
  });

  /// Test the connection / API key validity
  Future<bool> testConnection();
}

/// Result of an AI chat interaction
class AiChatResult {
  /// The AI's text response to display in chat
  final String textResponse;

  /// Structured wine data extracted (empty list if no wine data found)
  final List<WineAiResponse> wineDataList;

  /// Whether an error occurred
  final bool isError;

  /// Error message if applicable
  final String? errorMessage;

  const AiChatResult({
    required this.textResponse,
    this.wineDataList = const [],
    this.isError = false,
    this.errorMessage,
  });

  factory AiChatResult.error(String message) {
    return AiChatResult(
      textResponse: message,
      isError: true,
      errorMessage: message,
    );
  }
}
