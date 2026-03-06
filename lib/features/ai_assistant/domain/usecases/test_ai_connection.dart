import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';

/// Test the connection to the currently configured AI service.
///
/// Returns `true` when the connection is healthy, or a [Failure] on error.
class TestAiConnectionUseCase implements UseCase<bool, NoParams> {
  final AiService _aiService;

  const TestAiConnectionUseCase(this._aiService);

  @override
  Future<Either<Failure, bool>> call(NoParams _) async {
    try {
      final ok = await _aiService.testConnection();
      if (!ok) {
        return const Left(
          AiFailure('Le test de connexion a échoué. Vérifiez votre clé API.'),
        );
      }
      return const Right(true);
    } catch (e) {
      return Left(
        AiFailure('Impossible de tester la connexion.', cause: e),
      );
    }
  }
}
