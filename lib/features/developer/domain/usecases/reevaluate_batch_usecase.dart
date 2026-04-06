import 'dart:convert';

import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/food_pairing_catalog.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/developer/domain/entities/reevaluation_options.dart';
import 'package:wine_cellar/features/developer/domain/entities/wine_reevaluation_change.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Parameters for [ReevaluateBatchUseCase].
class ReevaluateBatchParams {
  /// At most [_batchSize] wines to evaluate in a single AI call.
  final List<WineEntity> wines;
  final ReevaluationOptions options;
  final AiService aiService;

  /// If non-null, used for web-search-first evaluation (Gemini grounding).
  final AiService? webSearchService;

  /// Pre-fetched food categories used to map AI-returned names to IDs.
  final List<FoodCategoryEntity> foodCategories;

  const ReevaluateBatchParams({
    required this.wines,
    required this.options,
    required this.aiService,
    this.webSearchService,
    required this.foodCategories,
  });
}

/// Sends a single batch of wines (≤ [_batchSize]) to the AI for re-evaluation
/// and returns a [WineReevaluationChange] per wine.
///
/// Strategy: web-search-first (Gemini Search Grounding) when available,
/// otherwise fall back to the configured AI service with a targeted prompt.
class ReevaluateBatchUseCase {
  const ReevaluateBatchUseCase();

  Future<Either<Failure, List<WineReevaluationChange>>> call(
    ReevaluateBatchParams params,
  ) async {
    if (params.wines.isEmpty) {
      return const Right([]);
    }

    if (!params.options.isValid) {
      return Left(ValidationFailure('Aucun type de réévaluation sélectionné.'));
    }

    final winesJson = params.wines
        .map((w) => _wineToPromptMap(w, params.options))
        .toList();

    final message = AiPrompts.buildBatchReevaluationMessage(
      winesJson: winesJson,
      evaluateDrinkingWindow: params.options.includesDrinkingWindow,
      evaluateFoodPairings: params.options.includesFoodPairings,
    );

    try {
      final AiChatResult result;

      if (params.webSearchService != null) {
        // Internet-first: more accurate for factual fields like drinking windows.
        result = await params.webSearchService!.analyzeWineWithWebSearch(
          userMessage: message,
          systemPromptOverride: AiPrompts.batchReevaluationSystemPrompt,
        );
      } else {
        result = await params.aiService.analyzeWine(
          userMessage:
              '${AiPrompts.batchReevaluationSystemPrompt}\n\n$message',
        );
      }

      if (result.isError) {
        // Mark all wines in this batch as errored.
        final errorMsg = result.errorMessage ?? 'Erreur IA inconnue.';
        return Right(
          params.wines
              .map((w) => WineReevaluationChange.error(w, errorMsg))
              .toList(),
        );
      }

      final parsed = _parseResponse(
        rawText: result.textResponse,
        originalWines: params.wines,
        options: params.options,
        foodCategories: params.foodCategories,
      );
      return Right(parsed);
    } catch (e) {
      return Left(
        AiFailure('Erreur lors de la réévaluation du lot.', cause: e),
      );
    }
  }

  // ---- Helpers ----

  /// Build the compact wine map sent to the AI.
  Map<String, dynamic> _wineToPromptMap(
    WineEntity w,
    ReevaluationOptions options,
  ) {
    final map = <String, dynamic>{
      'id': w.id,
      'name': w.name,
      if (w.vintage != null) 'vintage': w.vintage,
      if (w.producer != null) 'producer': w.producer,
      if (w.appellation != null) 'appellation': w.appellation,
      if (w.region != null) 'region': w.region,
      'color': w.color.name,
    };

    if (options.includesDrinkingWindow) {
      map['currentDrinkFromYear'] = w.drinkFromYear;
      map['currentDrinkUntilYear'] = w.drinkUntilYear;
    }

    if (options.includesFoodPairings && w.foodCategoryIds.isNotEmpty) {
      // Pass current pairing names for context so the AI knows the baseline.
      // We embed the names from the static catalog (no DB lookup needed).
      map['currentFoodPairings'] = w.foodCategoryIds
          .map((id) {
            final match = defaultFoodPairingCatalog.where(
              (p) => p.sortOrder == id,
            );
            return match.isEmpty ? id.toString() : match.first.name;
          })
          .toList();
    }

    return map;
  }

  /// Extract the JSON block from the AI response and map it to entities.
  List<WineReevaluationChange> _parseResponse({
    required String rawText,
    required List<WineEntity> originalWines,
    required ReevaluationOptions options,
    required List<FoodCategoryEntity> foodCategories,
  }) {
    final jsonMap = _extractJson(rawText);
    if (jsonMap == null) {
      // Cannot parse → mark all as error.
      return originalWines
          .map(
            (w) => WineReevaluationChange.error(
              w,
              'Réponse IA non parsable',
            ),
          )
          .toList();
    }

    final results = jsonMap['results'] as List<dynamic>?;
    if (results == null) {
      return originalWines
          .map(
            (w) => WineReevaluationChange.error(
              w,
              'Format de réponse inattendu',
            ),
          )
          .toList();
    }

    final wineById = {for (final w in originalWines) w.id: w};
    final changes = <WineReevaluationChange>[];

    for (final rawResult in results) {
      if (rawResult is! Map<String, dynamic>) continue;

      final wineId = _asInt(rawResult['wineId']);
      final wine = wineId != null ? wineById[wineId] : null;
      if (wine == null) continue;

      final unchanged = rawResult['unchanged'] as bool? ?? false;
      if (unchanged) {
        changes.add(WineReevaluationChange.unchanged(wine));
        continue;
      }

      int? newFrom;
      int? newUntil;
      if (options.includesDrinkingWindow) {
        newFrom = _asInt(rawResult['drinkFromYear']);
        newUntil = _asInt(rawResult['drinkUntilYear']);
      }

      List<int>? newIds;
      List<String>? newNames;
      if (options.includesFoodPairings) {
        final rawPairings =
            (rawResult['suggestedFoodPairings'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList();
        if (rawPairings != null) {
          newIds = _mapPairingNamesToCategoryIds(rawPairings, foodCategories);
          newNames = rawPairings;
        }
      }

      changes.add(
        WineReevaluationChange(
          originalWine: wine,
          newDrinkFromYear: newFrom,
          newDrinkUntilYear: newUntil,
          newFoodCategoryIds: newIds,
          newFoodPairingNames: newNames,
        ),
      );
    }

    // Any wine not found in the AI response is marked as unchanged.
    final returnedIds = changes.map((c) => c.originalWine.id).toSet();
    for (final wine in originalWines) {
      if (!returnedIds.contains(wine.id)) {
        changes.add(WineReevaluationChange.unchanged(wine));
      }
    }

    return changes;
  }

  /// Map AI-returned food pairing names to DB category IDs.
  List<int> _mapPairingNamesToCategoryIds(
    List<String> names,
    List<FoodCategoryEntity> categories,
  ) {
    final ids = <int>[];
    for (final name in names) {
      final match = categories.where(
        (c) =>
            c.name.toLowerCase().contains(name.toLowerCase()) ||
            name.toLowerCase().contains(c.name.toLowerCase()),
      );
      if (match.isNotEmpty) ids.add(match.first.id);
    }
    return ids;
  }

  /// Extract a JSON object from text containing a json block.
  Map<String, dynamic>? _extractJson(String text) {
    // 1. Try <json>…</json> tags (preferred format in our prompts).
    final tagRegex = RegExp(r'<json>([\s\S]*?)<\/json>');
    final tagMatch = tagRegex.firstMatch(text);
    if (tagMatch != null) {
      try {
        final decoded = jsonDecode(tagMatch.group(1)!.trim());
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // 2. Try ```json … ``` block.
    final codeBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final codeMatch = codeBlockRegex.firstMatch(text);
    if (codeMatch != null) {
      try {
        final decoded = jsonDecode(codeMatch.group(1)!.trim());
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // 3. Try raw JSON object.
    final braceStart = text.indexOf('{');
    final braceEnd = text.lastIndexOf('}');
    if (braceStart >= 0 && braceEnd > braceStart) {
      try {
        final decoded = jsonDecode(text.substring(braceStart, braceEnd + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }
}
