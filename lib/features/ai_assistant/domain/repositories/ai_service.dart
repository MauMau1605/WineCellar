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

  /// Analyze a wine image directly and return structured data.
  Future<AiChatResult> analyzeWineFromImage({
    required List<int> imageBytes,
    required String mimeType,
    String userMessage,
    List<Map<String, String>> conversationHistory = const [],
  });

  /// Test the connection / API key validity
  Future<bool> testConnection();

  /// Discovers which vision-capable model is available for this service.
  /// Returns the model name if vision is supported, null otherwise.
  /// Implementations that auto-discover a fallback model should cache the result.
  Future<String?> discoverVisionModel() async => null;

  /// Whether this service supports web-grounded search (e.g. Gemini Search).
  bool get supportsWebSearch => false;

  /// Analyze wine using web search grounding for verified information.
  /// Default implementation falls back to regular [analyzeWine].
  /// [systemPromptOverride] replaces the default grounded review prompt.
  Future<AiChatResult> analyzeWineWithWebSearch({
    required String userMessage,
    List<Map<String, String>> conversationHistory = const [],
    String? systemPromptOverride,
  }) async {
    return analyzeWine(
      userMessage: userMessage,
      conversationHistory: conversationHistory,
    );
  }
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

  /// Web sources used for grounded responses (URLs + titles).
  final List<WebSource> webSources;

  const AiChatResult({
    required this.textResponse,
    this.wineDataList = const [],
    this.isError = false,
    this.errorMessage,
    this.webSources = const [],
  });

  factory AiChatResult.error(String message) {
    return AiChatResult(
      textResponse: message,
      isError: true,
      errorMessage: message,
    );
  }
}

/// A web source returned by grounded search.
class WebSource {
  final String uri;
  final String title;

  const WebSource({required this.uri, required this.title});
}
