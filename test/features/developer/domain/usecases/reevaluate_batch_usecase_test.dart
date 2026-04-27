import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/developer/domain/entities/reevaluation_options.dart';
import 'package:wine_cellar/features/developer/domain/usecases/reevaluate_batch_usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

class _MockAiService extends Mock implements AiService {}

// ---- Helpers ----

AiChatResult _successResponse(Map<String, dynamic> json) => AiChatResult(
      textResponse: '<json>${jsonEncode(json)}</json>',
    );

AiChatResult _codeBlockResponse(Map<String, dynamic> json) => AiChatResult(
      textResponse: '```json\n${jsonEncode(json)}\n```',
    );

const _bordeaux = WineEntity(
  id: 1,
  name: 'Château Margaux',
  color: WineColor.red,
  vintage: 2015,
  appellation: 'Margaux',
  quantity: 1,
  drinkFromYear: 2025,
  drinkUntilYear: 2040,
);

const _chablis = WineEntity(
  id: 2,
  name: 'Chablis Premier Cru',
  color: WineColor.white,
  vintage: 2020,
  appellation: 'Chablis',
  quantity: 2,
);

final _foodCategories = [
  const FoodCategoryEntity(id: 1, name: 'Viande rouge', sortOrder: 1),
  const FoodCategoryEntity(id: 7, name: 'Fromage', sortOrder: 7),
  const FoodCategoryEntity(id: 5, name: 'Poisson', sortOrder: 5),
  const FoodCategoryEntity(id: 6, name: 'Fruits de mer', sortOrder: 6),
];

void main() {
  late _MockAiService aiService;
  late ReevaluateBatchUseCase useCase;

  setUp(() {
    aiService = _MockAiService();
    useCase = const ReevaluateBatchUseCase();
  });

  group('ReevaluateBatchUseCase', () {
    test('retourne une liste vide si aucun vin fourni', () async {
      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [],
          options: ReevaluationOptions.all,
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      expect(result.isRight(), isTrue);
      result.fold((_) {}, (changes) => expect(changes, isEmpty));
      verifyNever(() => aiService.analyzeWine(userMessage: any(named: 'userMessage')));
    });

    test('retourne une validation failure si aucune reevaluation n est selectionnee', () async {
      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux],
          options: const ReevaluationOptions(types: {}),
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Une ValidationFailure etait attendue.'),
      );
      verifyNever(() => aiService.analyzeWine(userMessage: any(named: 'userMessage')));
    });

    test('met à jour la fenêtre de dégustation quand l\'IA retourne de nouvelles valeurs', () async {
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer(
        (_) async => _successResponse({
          'results': [
            {
              'wineId': 1,
              'drinkFromYear': 2030,
              'drinkUntilYear': 2045,
              'unchanged': false,
            },
          ],
        }),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux],
          options: const ReevaluationOptions(
            types: {ReevaluationType.drinkingWindow},
          ),
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      expect(result.isRight(), isTrue);
      result.fold((_) {}, (changes) {
        expect(changes, hasLength(1));
        final change = changes.single;
        expect(change.hasDrinkingWindowChange, isTrue);
        expect(change.newDrinkFromYear, 2030);
        expect(change.newDrinkUntilYear, 2045);
        expect(change.unchanged, isFalse);
        expect(change.hasError, isFalse);
      });
    });

    test('marque le vin comme inchangé quand l\'IA retourne unchanged: true', () async {
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer(
        (_) async => _successResponse({
          'results': [
            {'wineId': 1, 'unchanged': true},
          ],
        }),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux],
          options: ReevaluationOptions.all,
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      result.fold((_) {}, (changes) {
        expect(changes.single.unchanged, isTrue);
        expect(changes.single.hasAnyChange, isFalse);
      });
    });

    test('met à jour les accords mets-vins avec les IDs correspondants', () async {
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer(
        (_) async => _successResponse({
          'results': [
            {
              'wineId': 2,
              'suggestedFoodPairings': ['Poisson', 'Fruits de mer'],
              'unchanged': false,
            },
          ],
        }),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_chablis],
          options: const ReevaluationOptions(
            types: {ReevaluationType.foodPairings},
          ),
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      result.fold((_) {}, (changes) {
        final change = changes.single;
        expect(change.hasFoodPairingsChange, isTrue);
        expect(change.newFoodCategoryIds, containsAll([5, 6]));
        expect(change.newFoodPairingNames, containsAll(['Poisson', 'Fruits de mer']));
      });
    });

    test('inclut les accords mets-vins actuels dans le prompt de reevaluation', () async {
      final wine = _bordeaux.copyWith(foodCategoryIds: [1, 7]);
      late String capturedUserMessage;

      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer((invocation) async {
        capturedUserMessage =
            invocation.namedArguments[#userMessage]! as String;
        return _successResponse({
          'results': [
            {'wineId': 1, 'unchanged': true},
          ],
        });
      });

      final result = await useCase(
        ReevaluateBatchParams(
          wines: [wine],
          options: const ReevaluationOptions(
            types: {ReevaluationType.foodPairings},
          ),
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      expect(result.isRight(), isTrue);
      expect(capturedUserMessage, contains('currentFoodPairings'));
      expect(capturedUserMessage, contains('Viande rouge'));
      expect(capturedUserMessage, contains('Fromage'));
    });

    test('utilise le service web search en priorité si fourni', () async {
      final webService = _MockAiService();
      when(
        () => webService.analyzeWineWithWebSearch(
          userMessage: any(named: 'userMessage'),
          systemPromptOverride: any(named: 'systemPromptOverride'),
        ),
      ).thenAnswer(
        (_) async => _successResponse({
          'results': [
            {'wineId': 1, 'drinkFromYear': 2032, 'drinkUntilYear': 2050, 'unchanged': false},
          ],
        }),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux],
          options: const ReevaluationOptions(
            types: {ReevaluationType.drinkingWindow},
          ),
          aiService: aiService,
          webSearchService: webService,
          foodCategories: _foodCategories,
        ),
      );

      // aiService.analyzeWine should NOT be called when web search service is available.
      verifyNever(() => aiService.analyzeWine(userMessage: any(named: 'userMessage')));
      verify(
        () => webService.analyzeWineWithWebSearch(
          userMessage: any(named: 'userMessage'),
          systemPromptOverride: any(named: 'systemPromptOverride'),
        ),
      ).called(1);

      result.fold((_) {}, (changes) {
        expect(changes.single.newDrinkFromYear, 2032);
      });
    });

    test('marque les vins en erreur si le service IA retourne une erreur', () async {
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer(
        (_) async => AiChatResult.error('Service indisponible'),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux, _chablis],
          options: ReevaluationOptions.all,
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      result.fold((_) {}, (changes) {
        expect(changes, hasLength(2));
        expect(changes.every((c) => c.hasError), isTrue);
        expect(changes.every((c) => c.errorMessage == 'Service indisponible'), isTrue);
      });
    });

    test('retourne une AiFailure si le service IA leve une exception', () async {
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenThrow(Exception('boom'));

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux],
          options: ReevaluationOptions.all,
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AiFailure>());
          expect(failure.message, 'Erreur lors de la réévaluation du lot.');
        },
        (_) => fail('Une AiFailure etait attendue.'),
      );
    });

    test('gère gracieusement une réponse JSON non parsable', () async {
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer(
        (_) async => const AiChatResult(
          textResponse: 'Voici une réponse sans JSON valide...',
        ),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux],
          options: ReevaluationOptions.all,
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      result.fold((_) {}, (changes) {
        expect(changes.single.hasError, isTrue);
      });
    });

    test('parse une reponse JSON dans un bloc de code et convertit les entiers stringifies', () async {
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer(
        (_) async => _codeBlockResponse({
          'results': [
            {
              'wineId': '1',
              'drinkFromYear': '2031',
              'drinkUntilYear': '2044',
              'unchanged': false,
            },
          ],
        }),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux],
          options: const ReevaluationOptions(
            types: {ReevaluationType.drinkingWindow},
          ),
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      result.fold((_) {}, (changes) {
        expect(changes.single.newDrinkFromYear, 2031);
        expect(changes.single.newDrinkUntilYear, 2044);
      });
    });

    test('marque tous les vins en erreur si la reponse JSON ne contient pas results', () async {
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer(
        (_) async => _successResponse({'status': 'ok'}),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux, _chablis],
          options: ReevaluationOptions.all,
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      result.fold((_) {}, (changes) {
        expect(changes, hasLength(2));
        expect(changes.every((change) => change.hasError), isTrue);
        expect(
          changes.every(
            (change) => change.errorMessage == 'Format de réponse inattendu',
          ),
          isTrue,
        );
      });
    });

    test('marque inchangé les vins absents de la réponse IA', () async {
      // IA ne répond que pour _bordeaux, pas _chablis.
      when(
        () => aiService.analyzeWine(
          userMessage: any(named: 'userMessage'),
          conversationHistory: any(named: 'conversationHistory'),
        ),
      ).thenAnswer(
        (_) async => _successResponse({
          'results': [
            {'wineId': 1, 'drinkFromYear': 2030, 'drinkUntilYear': 2045, 'unchanged': false},
          ],
        }),
      );

      final result = await useCase(
        ReevaluateBatchParams(
          wines: const [_bordeaux, _chablis],
          options: const ReevaluationOptions(
            types: {ReevaluationType.drinkingWindow},
          ),
          aiService: aiService,
          foodCategories: _foodCategories,
        ),
      );

      result.fold((_) {}, (changes) {
        expect(changes, hasLength(2));
        final bordeaux = changes.firstWhere((c) => c.originalWine.id == 1);
        final chablis = changes.firstWhere((c) => c.originalWine.id == 2);
        expect(bordeaux.hasDrinkingWindowChange, isTrue);
        expect(chablis.unchanged, isTrue);
      });
    });
  });
}
