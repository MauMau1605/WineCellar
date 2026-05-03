import 'package:fpdart/fpdart.dart' show Right;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_edit_screen.dart';

class _MockWineRepository extends Mock implements WineRepository {}

class _MockFoodCategoryRepository extends Mock
    implements FoodCategoryRepository {}

class _MockVirtualCellarRepository extends Mock
    implements VirtualCellarRepository {}

class _AutoPushHost extends StatefulWidget {
  const _AutoPushHost({required this.targetRoute});

  final String targetRoute;

  @override
  State<_AutoPushHost> createState() => _AutoPushHostState();
}

class _AutoPushHostState extends State<_AutoPushHost> {
  bool _pushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pushed) return;
    _pushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.push(widget.targetRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Écran retour factice')));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_sampleWine());
    registerFallbackValue(
      const VirtualCellarEntity(name: 'Fallback', rows: 5, columns: 5),
    );
  });

  group('WineEditScreen', () {
    late _MockWineRepository wineRepository;
    late _MockFoodCategoryRepository foodCategoryRepository;
    late _MockVirtualCellarRepository virtualCellarRepository;

    setUp(() {
      wineRepository = _MockWineRepository();
      foodCategoryRepository = _MockFoodCategoryRepository();
      virtualCellarRepository = _MockVirtualCellarRepository();

      when(
        () => foodCategoryRepository.getAllCategories(),
      ).thenAnswer((_) async => const <FoodCategoryEntity>[]);
      when(
        () => virtualCellarRepository.getAll(),
      ).thenAnswer((_) async => const Right(<VirtualCellarEntity>[]));
      when(
        () => virtualCellarRepository.create(any()),
      ).thenAnswer((_) async => const Right(1));
      when(() => wineRepository.updateWine(any())).thenAnswer((_) async {});
    });

    testWidgets('revient en arriere si le vin est introuvable', (tester) async {
      when(() => wineRepository.getWineById(99)).thenAnswer((_) async => null);

      await _pumpScreen(
        tester,
        wineRepository: wineRepository,
        foodCategoryRepository: foodCategoryRepository,
        virtualCellarRepository: virtualCellarRepository,
        wineId: 99,
      );

      expect(find.text('Écran retour factice'), findsOneWidget);
      expect(find.text('Modifier le vin'), findsNothing);
    });

    testWidgets('cree le cellier manquant puis sauvegarde le vin modifie', (
      tester,
    ) async {
      when(
        () => wineRepository.getWineById(7),
      ).thenAnswer((_) async => _sampleWine());

      await _pumpScreen(
        tester,
        wineRepository: wineRepository,
        foodCategoryRepository: foodCategoryRepository,
        virtualCellarRepository: virtualCellarRepository,
        wineId: 7,
      );

      final formScrollable = find.byType(Scrollable).first;

      Finder inputByLabel(String label) {
        final decorator = find.ancestor(
          of: find.text(label),
          matching: find.byType(InputDecorator),
        );
        return find.descendant(
          of: decorator,
          matching: find.byType(EditableText),
        );
      }

      await tester.enterText(inputByLabel('Nom du vin *'), 'Chablis Modifié');
      await tester.scrollUntilVisible(
        find.text('Localisation'),
        300,
        scrollable: formScrollable,
      );
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('Localisation'), 'Nouveau cellier');
      await tester.scrollUntilVisible(
        find.text('À boire dès'),
        300,
        scrollable: formScrollable,
      );
      await tester.pumpAndSettle();
      await tester.enterText(inputByLabel('À boire dès'), '2022');

      await tester.tap(find.byTooltip('Enregistrer'));
      await tester.pumpAndSettle();

      final createdCellar =
          verify(
                () => virtualCellarRepository.create(captureAny()),
              ).captured.single
              as VirtualCellarEntity;
      expect(createdCellar.name, 'Nouveau cellier');
      expect(createdCellar.rows, 5);
      expect(createdCellar.columns, 5);

      final updatedWine =
          verify(() => wineRepository.updateWine(captureAny())).captured.single
              as WineEntity;
      expect(updatedWine.name, 'Chablis Modifié');
      expect(updatedWine.location, 'Nouveau cellier');
      expect(updatedWine.drinkFromYear, 2022);
      expect(updatedWine.aiSuggestedDrinkFromYear, isFalse);
      expect(find.text('Écran retour factice'), findsOneWidget);
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
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => const _AutoPushHost(targetRoute: '/edit'),
      ),
      GoRoute(
        path: '/edit',
        builder: (context, state) => WineEditScreen(wineId: wineId),
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

WineEntity _sampleWine() {
  return const WineEntity(
    id: 7,
    name: 'Chablis Test',
    country: 'France',
    color: WineColor.white,
    vintage: 2020,
    quantity: 3,
    drinkFromYear: 2020,
    aiSuggestedDrinkFromYear: true,
  );
}
