import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';

/// Parameters for [AnalyzeWineFromImageUseCase].
class AnalyzeWineFromImageParams {
  final List<int> imageBytes;
  final String mimeType;
  final String userMessage;
  final List<Map<String, String>> conversationHistory;

  const AnalyzeWineFromImageParams({
    required this.imageBytes,
    required this.mimeType,
    this.userMessage = 'Analyse cette photo de bouteille de vin.',
    this.conversationHistory = const [],
  });
}

/// Send a wine image to the AI service and return the analysis result.
///
/// This use case sends the raw image directly to the AI for analysis,
/// without local text extraction. The AI service handles image parsing.
class AnalyzeWineFromImageUseCase
    implements UseCase<AiChatResult, AnalyzeWineFromImageParams> {
  final AiService _aiService;

  const AnalyzeWineFromImageUseCase(this._aiService);

  @override
  Future<Either<Failure, AiChatResult>> call(
    AnalyzeWineFromImageParams params,
  ) async {
    try {
      // Validate image bytes
      if (params.imageBytes.isEmpty) {
        return const Left(ValidationFailure('L\'image ne peut pas être vide.'));
      }

      // Validate MIME type
      if (!_isValidMimeType(params.mimeType)) {
        return const Left(
          ValidationFailure(
            'Type MIME invalide. Utilisez "image/jpeg", "image/png", ou "image/webp".',
          ),
        );
      }

      final result = await _aiService.analyzeWineFromImage(
        imageBytes: params.imageBytes,
        mimeType: params.mimeType,
        userMessage: params.userMessage,
        conversationHistory: params.conversationHistory,
      );

      if (result.isError) {
        return Left(AiFailure(result.errorMessage ?? 'Erreur IA inconnue.'));
      }

      return Right(result);
    } catch (e) {
      return Left(
        AiFailure(
          'Erreur lors de l\'analyse de l\'image.',
          cause: e,
        ),
      );
    }
  }

  bool _isValidMimeType(String mimeType) {
    const validTypes = [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
      'image/gif',
    ];
    return validTypes.contains(mimeType.toLowerCase());
  }
}
