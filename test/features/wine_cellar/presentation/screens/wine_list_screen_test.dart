import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_import_row.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_list_screen.dart';

class _MockWineRepository extends Mock implements WineRepository {}

class _MockVirtualCellarRepository extends Mock
    implements VirtualCellarRepository {}

void main() {
  group('WineListScreen', () {
    late _MockWineRepository wineRepository;
    late _MockVirtualCellarRepository virtualCellarRepository;

    setUpAll(() {
      registerFallbackValue(const WineFilter());
    });

    setUp(() {
      wineRepository = _MockWineRepository();
      virtualCellarRepository = _MockVirtualCellarRepository();

      when(
        () => wineRepository.watchAllWines(),
      ).thenAnswer((_) => const Stream<List<WineEntity>>.empty());
      when(() => virtualCellarRepository.getAll()).thenAnswer(
        (_) async => const Right([
          VirtualCellarEntity(
            id: 1,
            name: 'Cellier principal',
            rows: 5,
            columns: 5,
          ),
          VirtualCellarEntity(
            id: 2,
            name: 'Cellier secondaire',
            rows: 4,
            columns: 6,
          ),
        ]),
      );
    });

    testWidgets('affiche l etat vide et navigue vers ajout et manuel', (
      tester,
    ) async {
      when(
        () => wineRepository.watchFilteredWines(any()),
      ).thenAnswer((_) => Stream.value(const <WineEntity>[]));

      final router = await _pumpScreen(
        tester,
        wineRepository: wineRepository,
        virtualCellarRepository: virtualCellarRepository,
      );

      expect(find.text('Aucun vin dans votre cave'), findsOneWidget);
      expect(
        find.text('Utilisez l\'assistant IA pour ajouter votre premier vin'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Manuel utilisateur'));
      await tester.pumpAndSettle();
      expect(find.text('Écran manuel factice'), findsOneWidget);

      router.go('/cellar');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter un vin'));
      await tester.pumpAndSettle();
      expect(find.text('Écran ajout factice'), findsOneWidget);
    });

    testWidgets('filtre la liste par recherche et localisation', (
      tester,
    ) async {
      final wines = [
        WineEntity(
          id: 1,
          name: 'Chablis Test',
          country: 'France',
          color: WineColor.white,
          vintage: 2020,
          location: 'Cellier principal',
        ),
        WineEntity(
          id: 2,
          name: 'Bordeaux Test',
          country: 'France',
          color: WineColor.red,
          vintage: 2018,
          location: 'Cellier secondaire',
        ),
      ];

      when(() => wineRepository.watchFilteredWines(any())).thenAnswer((
        invocation,
      ) {
        final filter = invocation.positionalArguments[0] as WineFilter;
        final query = filter.searchQuery?.toLowerCase().trim() ?? '';
        final filtered = query.isEmpty
            ? wines
            : wines
                  .where(
                    (wine) => wine.displayName.toLowerCase().contains(query),
                  )
                  .toList();
        return Stream.value(filtered);
      });

      await _pumpScreen(
        tester,
        wineRepository: wineRepository,
        virtualCellarRepository: virtualCellarRepository,
      );

      expect(find.text('Chablis Test'), findsOneWidget);
      expect(find.text('Bordeaux Test'), findsOneWidget);

      await tester.enterText(_findTextField('Rechercher...'), 'chablis');
      await tester.pumpAndSettle();

      expect(find.text('Chablis Test'), findsOneWidget);
      expect(find.text('Bordeaux Test'), findsNothing);

      await tester.enterText(_findTextField('Rechercher...'), '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cellier secondaire'));
      await tester.pumpAndSettle();

      expect(find.text('Bordeaux Test'), findsOneWidget);
      expect(find.text('Chablis Test'), findsNothing);

      await tester.tap(find.text('Tout effacer'));
      await tester.pumpAndSettle();

      expect(find.text('Chablis Test'), findsOneWidget);
      expect(find.text('Bordeaux Test'), findsOneWidget);
    });
  });
}

Future<GoRouter> _pumpScreen(
  WidgetTester tester, {
  required WineRepository wineRepository,
  required VirtualCellarRepository virtualCellarRepository,
}) async {
  final router = GoRouter(
    initialLocation: '/cellar',
    routes: [
      GoRoute(
        path: '/cellar',
        builder: (context, state) => const WineListScreen(),
      ),
      GoRoute(
        path: '/cellar/add',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Écran ajout factice'))),
      ),
      GoRoute(
        path: '/manual',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Écran manuel factice'))),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wineRepositoryProvider.overrideWithValue(wineRepository),
        virtualCellarRepositoryProvider.overrideWithValue(
          virtualCellarRepository,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder _findTextField(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );
}
