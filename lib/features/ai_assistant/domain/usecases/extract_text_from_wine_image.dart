import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/image_text_extractor.dart';

class ExtractTextFromWineImageParams {
  final String imagePath;

  const ExtractTextFromWineImageParams({required this.imagePath});
}

class ExtractTextFromWineImageUseCase
    implements UseCase<String, ExtractTextFromWineImageParams> {
  final ImageTextExtractor _imageTextExtractor;

  const ExtractTextFromWineImageUseCase(this._imageTextExtractor);

  @override
  Future<Either<Failure, String>> call(
    ExtractTextFromWineImageParams params,
  ) async {
    final path = params.imagePath.trim();
    if (path.isEmpty) {
      return const Left(ValidationFailure('Chemin d\'image invalide.'));
    }

    try {
      final text = await _imageTextExtractor.extractTextFromImage(path);
      final normalizedText = text.trim();
      if (normalizedText.isEmpty) {
        return const Left(
          ValidationFailure(
            'Aucun texte détecté sur la photo. Essayez avec une image plus nette.',
          ),
        );
      }
      return Right(normalizedText);
    } catch (e) {
      return Left(
        AiFailure(
          'Impossible d\'extraire le texte depuis la photo.',
          cause: e,
        ),
      );
    }
  }
}
