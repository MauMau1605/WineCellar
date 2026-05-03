import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_detail_screen.dart';

class _MockWineRepository extends Mock implements WineRepository {}

class _MockFoodCategoryRepository extends Mock
    implements FoodCategoryRepository {}

class _MockVirtualCellarRepository extends Mock
    implements VirtualCellarRepository {}

void main() {
  group('WineDetailScreen', () {
    late _MockWineRepository wineRepository;
    late _MockFoodCategoryRepository foodCategoryRepository;
    late _MockVirtualCellarRepository virtualCellarRepository;

    setUp(() {
      wineRepository = _MockWineRepository();
      foodCategoryRepository = _MockFoodCategoryRepository();
      virtualCellarRepository = _MockVirtualCellarRepository();

      when(
        () => foodCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => const []);
      when(
        () => virtualCellarRepository.getPlacementsByWineId(any()),
      ).thenAnswer((_) async => const Right(<BottlePlacementEntity>[]));
      when(
        () => virtualCellarRepository.getAll(),
      ).thenAnswer((_) async => const Right(<VirtualCellarEntity>[]));
      when(
        () => wineRepository.updateQuantity(any(), any()),
      ).thenAnswer((_) async {});
      when(() => wineRepository.deleteWine(any())).thenAnswer((_) async {});
    });

    testWidgets('affiche l etat introuvable quand le vin est absent', (
      tester,
    ) async {
      when(() => wineRepository.getWineById(42)).thenAnswer((_) async => null);

      await _pumpScreen(
        tester,
        wineRepository: wineRepository,
        foodCategoryRepository: foodCategoryRepository,
        virtualCellarRepository: virtualCellarRepository,
        wineId: 42,
      );

      expect(find.text('Vin non trouvé'), findsOneWidget);
      expect(find.text('Ce vin n\'existe pas.'), findsOneWidget);
    });

    testWidgets('supprime le vin quand la quantite passe a zero', (
      tester,
    ) async {
      when(
        () => wineRepository.getWineById(7),
      ).thenAnswer((_) async => _sampleWine(quantity: 1));

      await _pumpScreen(
        tester,
        wineRepository: wineRepository,
        foodCategoryRepository: foodCategoryRepository,
        virtualCellarRepository: virtualCellarRepository,
        wineId: 7,
      );

      expect(find.text('Chablis Test 2020'), findsWidgets);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      expect(find.text('Dernière bouteille !'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      await tester.pumpAndSettle();

      verify(() => wineRepository.deleteWine(7)).called(1);
      expect(find.text('Vin supprimé'), findsOneWidget);
      expect(find.text('Écran cave factice'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required WineRepository wineRepository,
  required FoodCategoryRepository foodCategoryRepository,
  required VirtualCellarRepository virtualCellarRepository,
  required int wineId,
}) async {
  final router = GoRouter(
    initialLocation: '/detail',
    routes: [
      GoRoute(
        path: '/detail',
        builder: (context, state) => WineDetailScreen(wineId: wineId),
      ),
      GoRoute(
        path: '/cellar',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Écran cave factice'))),
      ),
      GoRoute(
        path: '/cellar/wine/:id/edit',
        builder: (context, state) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/cellars/:id',
        builder: (context, state) => const Scaffold(body: SizedBox()),
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
        virtualCellarRepositoryProvider.overrideWithValue(
          virtualCellarRepository,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

WineEntity _sampleWine({required int quantity}) {
  return WineEntity(
    id: 7,
    name: 'Chablis Test',
    country: 'France',
    color: WineColor.white,
    vintage: 2020,
    quantity: quantity,
  );
}
