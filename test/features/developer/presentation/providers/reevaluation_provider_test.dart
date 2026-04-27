import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/gemini_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/developer/domain/entities/reevaluation_options.dart';
import 'package:wine_cellar/features/developer/domain/entities/wine_reevaluation_change.dart';
import 'package:wine_cellar/features/developer/domain/usecases/reevaluate_batch_usecase.dart';
import 'package:wine_cellar/features/developer/presentation/providers/reevaluation_provider.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine.dart';

class _MockReevaluateBatchUseCase extends Mock
    implements ReevaluateBatchUseCase {}

class _MockAiService extends Mock implements AiService {}

class _MockGeminiService extends Mock implements GeminiService {}

class _MockFoodCategoryRepository extends Mock
    implements FoodCategoryRepository {}

class _MockUpdateWineUseCase extends Mock implements UpdateWineUseCase {}

class _FakeReevaluateBatchParams extends Fake
    implements ReevaluateBatchParams {}

const _wine1 = WineEntity(
  id: 1,
  name: 'Chateau Margaux',
  color: WineColor.red,
  vintage: 2015,
  quantity: 1,
  drinkFromYear: 2025,
  drinkUntilYear: 2040,
  foodCategoryIds: [1],
);

const _wine2 = WineEntity(
  id: 2,
  name: 'Chablis Premier Cru',
  color: WineColor.white,
  vintage: 2020,
  quantity: 1,
);

const _wine3 = WineEntity(
  id: 3,
  name: 'Cote Rotie',
  color: WineColor.red,
  vintage: 2018,
  quantity: 1,
);

const _foodCategories = [
  FoodCategoryEntity(id: 1, name: 'Viande rouge', sortOrder: 1),
  FoodCategoryEntity(id: 5, name: 'Poisson', sortOrder: 5),
  FoodCategoryEntity(id: 6, name: 'Fruits de mer', sortOrder: 6),
];

ProviderContainer _createContainer({
  required ReevaluateBatchUseCase useCase,
  required AiService? aiService,
  required FoodCategoryRepository foodCategoryRepository,
  required UpdateWineUseCase updateWineUseCase,
  GeminiService? geminiService,
}) {
  return ProviderContainer(
    overrides: [
      reevaluateBatchUseCaseProvider.overrideWith((ref) => useCase),
      aiServiceProvider.overrideWith((ref) => aiService),
      geminiWebSearchServiceProvider.overrideWith((ref) => geminiService),
      foodCategoryRepositoryProvider.overrideWith(
        (ref) => foodCategoryRepository,
      ),
      updateWineUseCaseProvider.overrideWith((ref) => updateWineUseCase),
    ],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_wine1);
    registerFallbackValue(_FakeReevaluateBatchParams());
  });

  late _MockReevaluateBatchUseCase useCase;
  late _MockAiService aiService;
  late _MockFoodCategoryRepository foodCategoryRepository;
  late _MockUpdateWineUseCase updateWineUseCase;

  setUp(() {
    useCase = _MockReevaluateBatchUseCase();
    aiService = _MockAiService();
    foodCategoryRepository = _MockFoodCategoryRepository();
    updateWineUseCase = _MockUpdateWineUseCase();

    when(
      () => foodCategoryRepository.getAllCategories(),
    ).thenAnswer((_) async => _foodCategories);
  });

  group('ReevaluationNotifier', () {
    test('retourne une erreur si aucun service IA n est configure', () async {
      final container = _createContainer(
        useCase: useCase,
        aiService: null,
        foodCategoryRepository: foodCategoryRepository,
        updateWineUseCase: updateWineUseCase,
      );
      addTearDown(container.dispose);

      final notifier = container.read(reevaluationNotifierProvider.notifier);

      await notifier.startReevaluation(
        const [_wine1],
        ReevaluationOptions.all,
      );

      final state = container.read(reevaluationNotifierProvider);
      expect(state, isA<ReevaluationError>());
      expect(
        (state as ReevaluationError).message,
        'Aucun service IA configuré. Configurez une clé API dans les paramètres.',
      );
      verifyNever(() => useCase(any()));
    });

    test('traite les vins par lots et preselectionne uniquement ceux modifies', () async {
      final wines = List.generate(
        11,
        (index) => _wine2.copyWith(
          id: index + 1,
          name: 'Vin ${index + 1}',
          drinkFromYear: 2020 + index,
        ),
      );
      final states = <ReevaluationState>[];

      when(() => useCase(any())).thenAnswer((invocation) async {
        final params = invocation.positionalArguments.single
            as ReevaluateBatchParams;
        return Right(
          params.wines.map((wine) {
            if (wine.id == 1 || wine.id == 11) {
              return WineReevaluationChange(
                originalWine: wine,
                newDrinkFromYear: (wine.drinkFromYear ?? 2020) + 2,
              );
            }
            return WineReevaluationChange.unchanged(wine);
          }).toList(),
        );
      });

      final container = _createContainer(
        useCase: useCase,
        aiService: aiService,
        foodCategoryRepository: foodCategoryRepository,
        updateWineUseCase: updateWineUseCase,
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        reevaluationNotifierProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container
          .read(reevaluationNotifierProvider.notifier)
          .startReevaluation(
            wines,
            const ReevaluationOptions(
              types: {ReevaluationType.drinkingWindow},
            ),
          );

      final state = container.read(reevaluationNotifierProvider);
      expect(state, isA<ReevaluationPreview>());
      final preview = state as ReevaluationPreview;
      expect(preview.selectedWineIds, {1, 11});

      final processingStates = states.whereType<ReevaluationProcessing>().toList();
      expect(processingStates, hasLength(2));
      expect(processingStates.first.currentBatch, 1);
      expect(processingStates.first.totalBatches, 2);
      expect(processingStates.last.currentBatch, 2);
      expect(processingStates.last.processedWines, 10);

      verify(() => useCase(any())).called(2);
    });

    test('applySelected ne persiste que les vins selectionnes avec changements', () async {
      when(() => useCase(any())).thenAnswer(
        (_) async => Right([
          const WineReevaluationChange(
            originalWine: _wine1,
            newDrinkFromYear: 2030,
            newDrinkUntilYear: 2045,
            newFoodCategoryIds: [5, 6],
            newFoodPairingNames: ['Poisson', 'Fruits de mer'],
          ),
          const WineReevaluationChange(
            originalWine: _wine2,
            newDrinkFromYear: 2028,
            newDrinkUntilYear: 2034,
          ),
          WineReevaluationChange.unchanged(_wine3),
        ]),
      );
      when(
        () => updateWineUseCase(any()),
      ).thenAnswer((_) async => const Right(null));

      final container = _createContainer(
        useCase: useCase,
        aiService: aiService,
        foodCategoryRepository: foodCategoryRepository,
        updateWineUseCase: updateWineUseCase,
      );
      addTearDown(container.dispose);

      final notifier = container.read(reevaluationNotifierProvider.notifier);
      await notifier.startReevaluation(
        const [_wine1, _wine2, _wine3],
        ReevaluationOptions.all,
      );
      notifier.toggleWineSelection(2);

      await notifier.applySelected();

      final state = container.read(reevaluationNotifierProvider);
      expect(state, isA<ReevaluationApplied>());
      expect((state as ReevaluationApplied).appliedCount, 1);
      expect(state.unchangedCount, 1);
      expect(state.errorCount, 0);

      final captured = verify(
        () => updateWineUseCase(captureAny()),
      ).captured.single as WineEntity;
      expect(captured.id, 1);
      expect(captured.drinkFromYear, 2030);
      expect(captured.drinkUntilYear, 2045);
      expect(captured.aiSuggestedDrinkFromYear, isTrue);
      expect(captured.aiSuggestedDrinkUntilYear, isTrue);
      expect(captured.foodCategoryIds, [5, 6]);
      expect(captured.aiSuggestedFoodPairings, isTrue);
    });

    test('cancel remet le notifier a idle apres le lot en cours', () async {
      final completer =
          Completer<Either<Failure, List<WineReevaluationChange>>>();
      final useCaseStarted = Completer<void>();
      final states = <ReevaluationState>[];

      when(() => useCase(any())).thenAnswer((_) {
        if (!useCaseStarted.isCompleted) {
          useCaseStarted.complete();
        }
        return completer.future;
      });

      final container = _createContainer(
        useCase: useCase,
        aiService: aiService,
        foodCategoryRepository: foodCategoryRepository,
        updateWineUseCase: updateWineUseCase,
        geminiService: _MockGeminiService(),
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        reevaluationNotifierProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final notifier = container.read(reevaluationNotifierProvider.notifier);
      final reevaluationFuture = notifier.startReevaluation(
        const [_wine1],
        const ReevaluationOptions(
          types: {ReevaluationType.drinkingWindow},
        ),
      );

      await useCaseStarted.future;
      notifier.cancel();
      completer.complete(
        Right([
          const WineReevaluationChange(
            originalWine: _wine1,
            newDrinkFromYear: 2032,
          ),
        ]),
      );
      await reevaluationFuture;

      expect(states.any((state) => state is ReevaluationProcessing), isTrue);
      expect(
        container.read(reevaluationNotifierProvider),
        isA<ReevaluationIdle>(),
      );
    });
  });
}