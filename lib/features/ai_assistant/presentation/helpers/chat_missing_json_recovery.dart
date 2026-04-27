import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';

typedef ChatLogError = void Function(String message);
typedef ChatLogAiResponse = void Function(String response);

class ChatMissingJsonRecovery {
  final AnalyzeWineUseCase analyzeUseCase;
  final ChatLogError logError;
  final ChatLogAiResponse logAiResponse;

  const ChatMissingJsonRecovery({
    required this.analyzeUseCase,
    required this.logError,
    required this.logAiResponse,
  });

  Future<List<WineAiResponse>> recoverWineDataIfMissing({
    required List<Map<String, String>> baseHistory,
    required String originalUserMessage,
    required String assistantResponse,
  }) async {
    if (assistantResponse.trim().isEmpty) return const [];

    final repairHistory = <Map<String, String>>[
      ...baseHistory,
      {
        'role': 'user',
        'content': originalUserMessage,
      },
      {
        'role': 'assistant',
        'content': assistantResponse,
      },
    ];

    final repairEither = await analyzeUseCase(
      AnalyzeWineParams(
        userMessage: AiPrompts.buildMissingJsonRecoveryMessage(
          originalUserMessage: originalUserMessage,
          previousAssistantResponse: assistantResponse,
        ),
        conversationHistory: repairHistory,
      ),
    );

    return repairEither.fold(
      (failure) {
        logError('Échec de récupération de la fiche vin: ${failure.message}');
        return const <WineAiResponse>[];
      },
      (repairResult) {
        if (repairResult.wineDataList.isNotEmpty) {
          logAiResponse(repairResult.textResponse);
        }
        return repairResult.wineDataList;
      },
    );
  }
}