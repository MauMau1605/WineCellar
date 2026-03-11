import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/image_text_extractor.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/extract_text_from_wine_image.dart';

class _MockImageTextExtractor extends Mock implements ImageTextExtractor {}

void main() {
  late _MockImageTextExtractor extractor;
  late ExtractTextFromWineImageUseCase useCase;

  setUp(() {
    extractor = _MockImageTextExtractor();
    useCase = ExtractTextFromWineImageUseCase(extractor);
  });

  test('retourne ValidationFailure quand le chemin est vide', () async {
    final result = await useCase(
      const ExtractTextFromWineImageParams(imagePath: '  '),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('Le résultat devrait être un échec.'),
    );
    verifyNever(() => extractor.extractTextFromImage(any()));
  });

  test('retourne le texte extrait quand OCR réussit', () async {
    const imagePath = '/tmp/wine.jpg';
    const extractedText = 'Château Margaux 2015';

    when(() => extractor.extractTextFromImage(imagePath))
        .thenAnswer((_) async => extractedText);

    final result = await useCase(
      const ExtractTextFromWineImageParams(imagePath: imagePath),
    );

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Le résultat devrait être un succès.'),
      (text) => expect(text, extractedText),
    );
    verify(() => extractor.extractTextFromImage(imagePath)).called(1);
  });

  test('retourne ValidationFailure quand aucun texte détecté', () async {
    const imagePath = '/tmp/wine.jpg';

    when(() => extractor.extractTextFromImage(imagePath))
        .thenAnswer((_) async => '   ');

    final result = await useCase(
      const ExtractTextFromWineImageParams(imagePath: imagePath),
    );

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('Le résultat devrait être un échec.'),
    );
    verify(() => extractor.extractTextFromImage(imagePath)).called(1);
  });
}
