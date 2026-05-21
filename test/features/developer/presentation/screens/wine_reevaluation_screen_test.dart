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
import 'package:wine_cellar/features/developer/presentation/screens/wine_reevaluation_screen.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine.dart';

class _MockWineRepository extends Mock implements WineRepository {}

class _MockFoodCategoryRepository extends Mock
    implements FoodCategoryRepository {}

class _MockReevaluateBatchUseCase extends Mock
    implements ReevaluateBatchUseCase {}

class _MockAiService extends Mock implements AiService {}

class _MockUpdateWineUseCase extends Mock implements UpdateWineUseCase {}

class _FakeReevaluateBatchParams extends Fake
    implements ReevaluateBatchParams {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeReevaluateBatchParams());
    registerFallbackValue(_wineRouge);
  });

  group('WineReevaluationScreen', () {
    late _MockWineRepository wineRepository;
    late _MockFoodCategoryRepository foodCategoryRepository;
    late _MockReevaluateBatchUseCase useCase;
    late _MockAiService aiService;
    late _MockUpdateWineUseCase updateWineUseCase;

    setUp(() {
      wineRepository = _MockWineRepository();
      foodCategoryRepository = _MockFoodCategoryRepository();
      useCase = _MockReevaluateBatchUseCase();
      aiService = _MockAiService();
      updateWineUseCase = _MockUpdateWineUseCase();

      when(
        () => wineRepository.getAllWines(),
      ).thenAnswer((_) async => [_wineRouge, _wineBlanc]);
      when(
        () => foodCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => const <FoodCategoryEntity>[]);
      when(
        () => updateWineUseCase(any()),
      ).thenAnswer((_) async => const Right(null));
      when(() => useCase(any())).thenAnswer(
        (_) async => Right([
          const WineReevaluationChange(
            originalWine: _wineRouge,
            newDrinkFromYear: 2028,
          ),
        ]),
      );
    });

    testWidgets('filtre, recherche et selectionne les vins visibles', (
      tester,
    ) async {
      await _pumpReevaluationScreen(
        tester,
        wineRepository: wineRepository,
        foodCategoryRepository: foodCategoryRepository,
        useCase: useCase,
        aiService: aiService,
        updateWineUseCase: updateWineUseCase,
      );

      expect(find.text('Chateau Rouge 2018'), findsOneWidget);
      expect(find.text('Domaine Blanc 2021'), findsOneWidget);
      expect(find.text('0 vin(s) sélectionné(s)'), findsOneWidget);

      await tester.tap(find.text('Blanc'));
      await tester.pumpAndSettle();

      expect(find.text('Chateau Rouge 2018'), findsNothing);
      expect(find.text('Domaine Blanc 2021'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Domaine');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tout sélectionner'));
      await tester.pumpAndSettle();

      expect(find.text('1 vin(s) sélectionné(s)'), findsOneWidget);
      expect(find.text('Lancer la réévaluation (1 vin(s))'), findsOneWidget);
    });

    testWidgets('lance la reevaluation et navigue vers la previsualisation', (
      tester,
    ) async {
      await _pumpReevaluationScreen(
        tester,
        wineRepository: wineRepository,
        foodCategoryRepository: foodCategoryRepository,
        useCase: useCase,
        aiService: aiService,
        updateWineUseCase: updateWineUseCase,
      );

      await tester.tap(find.byKey(const ValueKey(1)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lancer la réévaluation (1 vin(s))'));
      await tester.pumpAndSettle();

      verify(() => useCase(any())).called(1);
      expect(find.text('Prévisualisation factice'), findsOneWidget);
    });
  });
}

Future<void> _pumpReevaluationScreen(
  WidgetTester tester, {
  required WineRepository wineRepository,
  required FoodCategoryRepository foodCategoryRepository,
  required ReevaluateBatchUseCase useCase,
  required AiService aiService,
  required UpdateWineUseCase updateWineUseCase,
}) async {
  final router = GoRouter(
    initialLocation: '/developer/reevaluate',
    routes: [
      GoRoute(
        path: '/developer/reevaluate',
        builder: (context, state) => const WineReevaluationScreen(),
      ),
      GoRoute(
        path: '/developer/reevaluate/preview',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Prévisualisation factice')),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wineRepositoryProvider.overrideWithValue(wineRepository),
        foodCategoryRepositoryProvider.overrideWithValue(
          foodCategoryRepository,
        ),
        reevaluateBatchUseCaseProvider.overrideWith((ref) => useCase),
        aiServiceProvider.overrideWith((ref) => aiService),
        geminiWebSearchServiceProvider.overrideWith((ref) => null),
        updateWineUseCaseProvider.overrideWith((ref) => updateWineUseCase),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

const _wineRouge = WineEntity(
  id: 1,
  name: 'Chateau Rouge',
  color: WineColor.red,
  vintage: 2018,
  quantity: 1,
  producer: 'Maison Rouge',
  appellation: 'Bordeaux',
);

const _wineBlanc = WineEntity(
  id: 2,
  name: 'Domaine Blanc',
  color: WineColor.white,
  vintage: 2021,
  quantity: 1,
  producer: 'Maison Blanche',
  appellation: 'Chablis',
);
