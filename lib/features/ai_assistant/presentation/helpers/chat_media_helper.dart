import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';

enum ChatMediaMode { addWine, foodPairing, wineReview }

class ChatMediaHelper {
  ChatMediaHelper._();

  static String guessMimeTypeFromPath(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String buildImagePromptForMode({
    required ChatMediaMode mode,
    String? extractedText,
  }) {
    switch (mode) {
      case ChatMediaMode.addWine:
        return AiPrompts.buildAddWineImageMessage(
          extractedText: extractedText,
        );
      case ChatMediaMode.foodPairing:
        return AiPrompts.buildFoodPairingFromImageMessage(
          extractedText: extractedText,
        );
      case ChatMediaMode.wineReview:
        return AiPrompts.buildWineReviewFromImageMessage(
          extractedText: extractedText,
        );
    }
  }

  static String buildPhotoSentMessage({required ChatMediaMode mode}) {
    switch (mode) {
      case ChatMediaMode.addWine:
        return '🔍 Photo analysée en mode ajout...';
      case ChatMediaMode.foodPairing:
        return '🔍 Photo analysée en mode accords mets-vin...';
      case ChatMediaMode.wineReview:
        return '🔍 Photo analysée en mode avis...';
    }
  }
}