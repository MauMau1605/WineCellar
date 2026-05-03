import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:wine_cellar/features/ai_assistant/domain/repositories/image_text_extractor.dart';

typedef MlKitTextRecognizerFactory = MlKitTextRecognizerClient Function();

abstract class MlKitTextRecognizerClient {
  Future<String> processFile(String imagePath);
  Future<void> close();
}

class _MlKitTextRecognizerClient implements MlKitTextRecognizerClient {
  final TextRecognizer _recognizer;

  _MlKitTextRecognizerClient()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> processFile(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  @override
  Future<void> close() => _recognizer.close();
}

/// On-device OCR implementation using Google ML Kit text recognition.
class MlKitImageTextExtractor implements ImageTextExtractor {
  final MlKitTextRecognizerFactory _recognizerFactory;

  MlKitImageTextExtractor({MlKitTextRecognizerFactory? recognizerFactory})
    : _recognizerFactory =
          recognizerFactory ?? (() => _MlKitTextRecognizerClient());

  @override
  Future<String> extractTextFromImage(String imagePath) async {
    final recognizer = _recognizerFactory();
    try {
      final recognizedText = await recognizer.processFile(imagePath);
      return recognizedText.trim();
    } finally {
      await recognizer.close();
    }
  }
}
