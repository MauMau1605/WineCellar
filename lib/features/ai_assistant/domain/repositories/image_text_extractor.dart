/// Abstraction for extracting text content from an image file.
abstract class ImageTextExtractor {
  /// Reads an image from [imagePath] and returns extracted plain text.
  ///
  /// Implementations may rely on on-device OCR engines.
  Future<String> extractTextFromImage(String imagePath);
}
