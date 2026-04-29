import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';

class ChatMissingFieldsHelper {
  ChatMissingFieldsHelper._();

  static WineColor? resolveInitialSelectedColor(String? colorName) {
    if (colorName == null) return null;
    return WineColor.values.where((color) => color.name == colorName).firstOrNull;
  }

  static bool canConfirm({
    required WineAiResponse wineData,
    required String enteredName,
    required WineColor? selectedColor,
  }) {
    final nameEmpty = wineData.name == null && enteredName.trim().isEmpty;
    final colorMissing = wineData.color == null && selectedColor == null;
    return !nameEmpty && !colorMissing;
  }

  static WineAiResponse completeWineData({
    required WineAiResponse wineData,
    required String enteredName,
    required WineColor? selectedColor,
  }) {
    return WineAiResponse(
      name: wineData.name ?? enteredName.trim(),
      color: wineData.color ?? selectedColor!.name,
      appellation: wineData.appellation,
      producer: wineData.producer,
      region: wineData.region,
      country: wineData.country,
      vintage: wineData.vintage,
      grapeVarieties: wineData.grapeVarieties,
      quantity: wineData.quantity,
      purchasePrice: wineData.purchasePrice,
      drinkFromYear: wineData.drinkFromYear,
      drinkUntilYear: wineData.drinkUntilYear,
      tastingNotes: wineData.tastingNotes,
      suggestedFoodPairings: wineData.suggestedFoodPairings,
      description: wineData.description,
      needsMoreInfo: wineData.needsMoreInfo,
      followUpQuestion: wineData.followUpQuestion,
      estimatedFields: wineData.estimatedFields,
      confidenceNotes: wineData.confidenceNotes,
    );
  }
}