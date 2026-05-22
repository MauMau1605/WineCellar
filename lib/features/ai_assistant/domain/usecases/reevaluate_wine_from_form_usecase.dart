import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_prompts.dart';

/// Parameters for [ReevaluateWineFromFormUseCase].
class ReevaluateWineFromFormParams {
  /// Current field values of the wine being edited.
  final WineAiResponse currentData;

  /// Field names that the user has locked (manually corrected).
  /// These will be preserved verbatim in the AI response.
  final Set<String> lockedFields;

  const ReevaluateWineFromFormParams({
    required this.currentData,
    required this.lockedFields,
  });
}

/// Re-evaluate a wine form using the AI, preserving user-corrected fields.
///
/// The AI will re-run a full evaluation on non-locked fields, using locked
/// field values as hard constraints.  Returns a new [WineAiResponse] with
/// locked field values merged back in, in case the AI erroneously changed them.
class ReevaluateWineFromFormUseCase
    implements UseCase<WineAiResponse, ReevaluateWineFromFormParams> {
  final AiService _aiService;

  const ReevaluateWineFromFormUseCase(this._aiService);

  @override
  Future<Either<Failure, WineAiResponse>> call(
    ReevaluateWineFromFormParams params,
  ) async {
    try {
      final wineFields = _toFieldMap(params.currentData);
      final prompt = AiPrompts.buildReevaluationWithLocksPrompt(
        wineFields: wineFields,
        lockedFields: params.lockedFields,
      );

      final result = await _aiService.analyzeWine(userMessage: prompt);

      if (result.isError) {
        return Left(AiFailure(result.errorMessage ?? 'Erreur IA inconnue.'));
      }

      if (result.wineDataList.isEmpty) {
        return Left(const AiFailure('La réévaluation n\'a retourné aucune fiche.'));
      }

      final aiResponse = result.wineDataList.first;
      // Merge locked fields back — AI should respect them, but we enforce it.
      final merged = _applyLocks(aiResponse, params.currentData, params.lockedFields);
      // Preserve fieldSources from original data
      final withSources = merged.withFieldSources(params.currentData.fieldSources);
      return Right(withSources);
    } catch (e) {
      return Left(AiFailure('Erreur lors de la réévaluation : $e'));
    }
  }

  Map<String, String?> _toFieldMap(WineAiResponse data) {
    return {
      'name': data.name,
      'appellation': data.appellation,
      'producer': data.producer,
      'region': data.region,
      'country': data.country,
      'color': data.color,
      if (data.vintage != null) 'vintage': data.vintage.toString(),
      if (data.grapeVarieties.isNotEmpty)
        'grapeVarieties': data.grapeVarieties.join(', '),
      if (data.quantity != null) 'quantity': data.quantity.toString(),
      if (data.purchasePrice != null)
        'purchasePrice': data.purchasePrice.toString(),
      if (data.drinkFromYear != null)
        'drinkFromYear': data.drinkFromYear.toString(),
      if (data.drinkUntilYear != null)
        'drinkUntilYear': data.drinkUntilYear.toString(),
      'tastingNotes': data.tastingNotes,
      if (data.suggestedFoodPairings.isNotEmpty)
        'suggestedFoodPairings': data.suggestedFoodPairings.join(', '),
    };
  }

  /// Enforce locked field values onto [aiResponse], using [original] as source.
  WineAiResponse _applyLocks(
    WineAiResponse aiResponse,
    WineAiResponse original,
    Set<String> lockedFields,
  ) {
    if (lockedFields.isEmpty) return aiResponse;

    return WineAiResponse(
      name: lockedFields.contains('name') ? original.name : aiResponse.name,
      appellation: lockedFields.contains('appellation')
          ? original.appellation
          : aiResponse.appellation,
      producer: lockedFields.contains('producer')
          ? original.producer
          : aiResponse.producer,
      region: lockedFields.contains('region')
          ? original.region
          : aiResponse.region,
      country: lockedFields.contains('country')
          ? original.country
          : aiResponse.country,
      color:
          lockedFields.contains('color') ? original.color : aiResponse.color,
      vintage: lockedFields.contains('vintage')
          ? original.vintage
          : aiResponse.vintage,
      grapeVarieties: lockedFields.contains('grapeVarieties')
          ? original.grapeVarieties
          : aiResponse.grapeVarieties,
      quantity: lockedFields.contains('quantity')
          ? original.quantity
          : aiResponse.quantity,
      purchasePrice: lockedFields.contains('purchasePrice')
          ? original.purchasePrice
          : aiResponse.purchasePrice,
      drinkFromYear: lockedFields.contains('drinkFromYear')
          ? original.drinkFromYear
          : aiResponse.drinkFromYear,
      drinkUntilYear: lockedFields.contains('drinkUntilYear')
          ? original.drinkUntilYear
          : aiResponse.drinkUntilYear,
      tastingNotes: lockedFields.contains('tastingNotes')
          ? original.tastingNotes
          : aiResponse.tastingNotes,
      suggestedFoodPairings: lockedFields.contains('suggestedFoodPairings')
          ? original.suggestedFoodPairings
          : aiResponse.suggestedFoodPairings,
      description: aiResponse.description,
      needsMoreInfo: aiResponse.needsMoreInfo,
      followUpQuestion: aiResponse.followUpQuestion,
      estimatedFields: aiResponse.estimatedFields
          .where((f) => !lockedFields.contains(f))
          .toList(),
      confidenceNotes: aiResponse.confidenceNotes,
    );
  }
}
