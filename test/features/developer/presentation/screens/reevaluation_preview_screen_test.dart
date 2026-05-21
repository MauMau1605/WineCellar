import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/developer/domain/entities/reevaluation_options.dart';
import 'package:wine_cellar/features/developer/domain/entities/wine_reevaluation_change.dart';
import 'package:wine_cellar/features/developer/domain/usecases/reevaluate_batch_usecase.dart';
import 'package:wine_cellar/features/developer/presentation/providers/reevaluation_provider.dart';
import 'package:wine_cellar/features/developer/presentation/screens/reevaluation_preview_screen.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine.dart';

class _MockReevaluateBatchUseCase extends Mock
    implements ReevaluateBatchUseCase {}

class _MockFoodCategoryRepository extends Mock
    implements FoodCategoryRepository {}

class _MockAiService extends Mock implements AiService {}

class _MockUpdateWineUseCase extends Mock implements UpdateWineUseCase {}

class _FakeReevaluateBatchParams extends Fake
    implements ReevaluateBatchParams {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeReevaluateBatchParams());
    registerFallbackValue(_wineChanged);
  });

  group('ReevaluationPreviewScreen', () {
    late _MockReevaluateBatchUseCase useCase;
    late _MockFoodCategoryRepository foodCategoryRepository;
    late _MockAiService aiService;
    late _MockUpdateWineUseCase updateWineUseCase;

    setUp(() {
      useCase = _MockReevaluateBatchUseCase();
      foodCategoryRepository = _MockFoodCategoryRepository();
      aiService = _MockAiService();
      updateWineUseCase = _MockUpdateWineUseCase();

      when(
        () => foodCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => const <FoodCategoryEntity>[]);
      when(
        () => updateWineUseCase(any()),
      ).thenAnswer((_) async => const Right(null));
    });

    testWidgets('affiche un message vide hors etat preview', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: const MaterialApp(home: ReevaluationPreviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun résultat de réévaluation disponible.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'affiche le resume et applique uniquement les vins selectionnes',
      (tester) async {
        when(() => useCase(any())).thenAnswer(
          (_) async => Right([
            const WineReevaluationChange(
              originalWine: _wineChanged,
              newDrinkFromYear: 2029,
              newDrinkUntilYear: 2035,
            ),
            WineReevaluationChange.unchanged(_wineUnchanged),
            WineReevaluationChange.error(_wineErrored, 'Erreur IA test'),
          ]),
        );

        final container = ProviderContainer(
          overrides: [
            reevaluateBatchUseCaseProvider.overrideWith((ref) => useCase),
            aiServiceProvider.overrideWith((ref) => aiService),
            geminiWebSearchServiceProvider.overrideWith((ref) => null),
            foodCategoryRepositoryProvider.overrideWith(
              (ref) => foodCategoryRepository,
            ),
            updateWineUseCaseProvider.overrideWith((ref) => updateWineUseCase),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(reevaluationNotifierProvider.notifier)
            .startReevaluation(
              const [_wineChanged, _wineUnchanged, _wineErrored],
              const ReevaluationOptions(
                types: {ReevaluationType.drinkingWindow},
              ),
            );

        final router = GoRouter(
          initialLocation: '/developer/reevaluate/preview',
          routes: [
            GoRoute(
              path: '/developer/reevaluate',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Retour réévaluation factice')),
              ),
            ),
            GoRoute(
              path: '/developer/reevaluate/preview',
              builder: (context, state) => const ReevaluationPreviewScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            '1 vin(s) à mettre à jour  ·  1 déjà à jour  ·  1 erreur(s)',
          ),
          findsOneWidget,
        );
        expect(find.text('Chateau Test 2017'), findsOneWidget);
        expect(find.text('Blanc Stable 2020'), findsOneWidget);
        expect(find.text('Erreur IA test'), findsOneWidget);

        await tester.tap(find.text('Chateau Test 2017'));
        await tester.pumpAndSettle();

        expect(find.text('Aucune sélection'), findsOneWidget);

        await tester.tap(find.text('Chateau Test 2017'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Appliquer (1 vin(s))'));
        await tester.pumpAndSettle();

        verify(() => updateWineUseCase(any())).called(1);
        expect(find.text('1 vin(s) mis à jour'), findsOneWidget);
        expect(find.text('1 vin(s) déjà à jour'), findsOneWidget);
        expect(find.text('1 erreur(s) ignorée(s)'), findsOneWidget);
      },
    );
  });
}

const _wineChanged = WineEntity(
  id: 1,
  name: 'Chateau Test',
  color: WineColor.red,
  vintage: 2017,
  quantity: 1,
  drinkFromYear: 2025,
  drinkUntilYear: 2032,
);

const _wineUnchanged = WineEntity(
  id: 2,
  name: 'Blanc Stable',
  color: WineColor.white,
  vintage: 2020,
  quantity: 1,
);

const _wineErrored = WineEntity(
  id: 3,
  name: 'Rose Fragile',
  color: WineColor.rose,
  vintage: 2021,
  quantity: 1,
);
