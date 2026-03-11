import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:wine_cellar/features/ai_assistant/domain/repositories/image_text_extractor.dart';

/// On-device OCR implementation using Google ML Kit text recognition.
class MlKitImageTextExtractor implements ImageTextExtractor {
  @override
  Future<String> extractTextFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
