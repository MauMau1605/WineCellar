import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/wine_add_screen.dart';

void main() {
  group('WineAddScreen cellar placement flow', () {
    testWidgets(
      'propose de creer une nouvelle cave 5x5 meme si des caves existent',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await db.virtualCellarDao.insertCellar(
          VirtualCellarsCompanion.insert(
            name: 'Cellier principal',
            rows: const Value(4),
            columns: const Value(6),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp.router(routerConfig: _testRouter()),
          ),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nom du vin *'),
          'Chablis Test',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Millésime *'),
          '2020',
        );

        await tester.tap(find.text('Ajouter ce vin manuellement'));
        await tester.pumpAndSettle();

        expect(find.text('Vin ajouté à la cave !'), findsOneWidget);

        await tester.tap(find.text('Associer à une cave'));
        await tester.pumpAndSettle();

        expect(find.text('Choisir une cave'), findsOneWidget);
        expect(find.text('Cellier principal'), findsOneWidget);
        expect(find.text('Créer une nouvelle cave (5×5)'), findsOneWidget);
      },
    );

    testWidgets(
      'cree automatiquement une cave standard 5x5 si aucune cave n existe',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp.router(routerConfig: _testRouter()),
          ),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nom du vin *'),
          'Saint Emilion Test',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Millésime *'),
          '2018',
        );

        await tester.tap(find.text('Ajouter ce vin manuellement'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Associer à une cave'));
        await tester.pumpAndSettle();

        final cellars = await db.virtualCellarDao.getAll();
        expect(cellars, hasLength(1));
        expect(cellars.single.rows, 5);
        expect(cellars.single.columns, 5);
      },
    );
  });
}

GoRouter _testRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WineAddScreen(),
      ),
      GoRoute(
        path: '/cellar/wine/:id',
        builder: (context, state) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/cellars/:id',
        builder: (context, state) => const Scaffold(body: SizedBox()),
      ),
    ],
  );
}
