import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/mlkit_image_text_extractor.dart';

class _FakeTextRecognizerClient implements MlKitTextRecognizerClient {
  _FakeTextRecognizerClient({this.text = '', this.error});

  final String text;
  final Object? error;
  final List<String> processedPaths = [];
  var closeCallCount = 0;

  @override
  Future<String> processFile(String imagePath) async {
    processedPaths.add(imagePath);
    if (error != null) {
      throw error!;
    }
    return text;
  }

  @override
  Future<void> close() async {
    closeCallCount += 1;
  }
}

void main() {
  group('MlKitImageTextExtractor', () {
    test('trim le texte OCR et transmet le chemin image', () async {
      final recognizer = _FakeTextRecognizerClient(
        text: '  Chateau Margaux  \n',
      );
      final extractor = MlKitImageTextExtractor(
        recognizerFactory: () => recognizer,
      );

      final result = await extractor.extractTextFromImage('/tmp/wine.jpg');

      expect(result, 'Chateau Margaux');
      expect(recognizer.processedPaths, ['/tmp/wine.jpg']);
      expect(recognizer.closeCallCount, 1);
    });

    test(
      'retourne une chaîne vide si le texte OCR ne contient que des espaces',
      () async {
        final recognizer = _FakeTextRecognizerClient(text: '   \n\t  ');
        final extractor = MlKitImageTextExtractor(
          recognizerFactory: () => recognizer,
        );

        final result = await extractor.extractTextFromImage('/tmp/empty.jpg');

        expect(result, isEmpty);
        expect(recognizer.closeCallCount, 1);
      },
    );

    test('ferme le recognizer même si l OCR échoue', () async {
      final recognizer = _FakeTextRecognizerClient(
        error: StateError('ocr failed'),
      );
      final extractor = MlKitImageTextExtractor(
        recognizerFactory: () => recognizer,
      );

      await expectLater(
        () => extractor.extractTextFromImage('/tmp/error.jpg'),
        throwsA(isA<StateError>()),
      );
      expect(recognizer.processedPaths, ['/tmp/error.jpg']);
      expect(recognizer.closeCallCount, 1);
    });
  });
}
