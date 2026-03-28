import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';

/// Parameters for [AnalyzeWineUseCase].
class AnalyzeWineParams {
  final String userMessage;
  final List<Map<String, String>> conversationHistory;
  final bool useWebSearch;

  const AnalyzeWineParams({
    required this.userMessage,
    this.conversationHistory = const [],
    this.useWebSearch = false,
  });
}

/// Send a user message to the AI service and return the analysis result.
///
/// This use case acts as the single entry-point between the presentation layer
/// and the AI service, ensuring all error handling is centralised.
class AnalyzeWineUseCase implements UseCase<AiChatResult, AnalyzeWineParams> {
  final AiService _aiService;

  const AnalyzeWineUseCase(this._aiService);

  @override
  Future<Either<Failure, AiChatResult>> call(AnalyzeWineParams params) async {
    try {
      final AiChatResult result;
      if (params.useWebSearch) {
        result = await _aiService.analyzeWineWithWebSearch(
          userMessage: params.userMessage,
          conversationHistory: params.conversationHistory,
        );
      } else {
        result = await _aiService.analyzeWine(
          userMessage: params.userMessage,
          conversationHistory: params.conversationHistory,
        );
      }

      if (result.isError) {
        return Left(AiFailure(result.errorMessage ?? 'Erreur IA inconnue.'));
      }

      return Right(result);
    } catch (e) {
      return Left(
        AiFailure('Erreur de communication avec le service IA.', cause: e),
      );
    }
  }
}
