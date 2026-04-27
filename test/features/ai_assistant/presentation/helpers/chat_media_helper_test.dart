import 'package:flutter_test/flutter_test.dart';

import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/helpers/chat_media_helper.dart';

void main() {
  group('ChatMediaHelper.guessMimeTypeFromPath', () {
    test('reconnait png et webp sans tenir compte de la casse', () {
      expect(
        ChatMediaHelper.guessMimeTypeFromPath('/tmp/photo.PNG'),
        'image/png',
      );
      expect(
        ChatMediaHelper.guessMimeTypeFromPath('/tmp/photo.WeBp'),
        'image/webp',
      );
    });

    test('retombe sur jpeg pour les autres extensions', () {
      expect(
        ChatMediaHelper.guessMimeTypeFromPath('/tmp/photo.jpg'),
        'image/jpeg',
      );
      expect(
        ChatMediaHelper.guessMimeTypeFromPath('/tmp/photo.unknown'),
        'image/jpeg',
      );
    });
  });

  group('ChatMediaHelper.buildImagePromptForMode', () {
    test('delegue au prompt ajout photo', () {
      expect(
        ChatMediaHelper.buildImagePromptForMode(
          mode: ChatMediaMode.addWine,
          extractedText: 'Chablis 2020',
        ),
        AiPrompts.buildAddWineImageMessage(extractedText: 'Chablis 2020'),
      );
    });

    test('delegue au prompt accords photo', () {
      expect(
        ChatMediaHelper.buildImagePromptForMode(
          mode: ChatMediaMode.foodPairing,
          extractedText: 'Chablis 2020',
        ),
        AiPrompts.buildFoodPairingFromImageMessage(
          extractedText: 'Chablis 2020',
        ),
      );
    });

    test('delegue au prompt avis photo', () {
      expect(
        ChatMediaHelper.buildImagePromptForMode(
          mode: ChatMediaMode.wineReview,
          extractedText: 'Chablis 2020',
        ),
        AiPrompts.buildWineReviewFromImageMessage(
          extractedText: 'Chablis 2020',
        ),
      );
    });
  });

  group('ChatMediaHelper.buildPhotoSentMessage', () {
    test('retourne le bon message pour chaque mode', () {
      expect(
        ChatMediaHelper.buildPhotoSentMessage(mode: ChatMediaMode.addWine),
        '🔍 Photo analysée en mode ajout...',
      );
      expect(
        ChatMediaHelper.buildPhotoSentMessage(mode: ChatMediaMode.foodPairing),
        '🔍 Photo analysée en mode accords mets-vin...',
      );
      expect(
        ChatMediaHelper.buildPhotoSentMessage(mode: ChatMediaMode.wineReview),
        '🔍 Photo analysée en mode avis...',
      );
    });
  });
}