import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/developer/presentation/screens/developer_screen.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/delete_all_wines.dart';

class _MockWineRepository extends Mock implements WineRepository {}

void main() {
  group('DeveloperScreen', () {
    late _MockWineRepository repository;

    setUp(() {
      repository = _MockWineRepository();
    });

    testWidgets('navigue vers l ecran de reevaluation', (tester) async {
      when(() => repository.getWineCount()).thenAnswer((_) async => 2);

      await _pumpScreen(tester, repository);

      expect(find.text('Outils développeur'), findsOneWidget);
      expect(find.text('Réévaluation IA des vins'), findsOneWidget);

      await tester.tap(find.text('Réévaluation IA des vins'));
      await tester.pumpAndSettle();

      expect(find.text('Écran réévaluation factice'), findsOneWidget);
    });

    testWidgets('supprime tous les vins apres confirmation', (tester) async {
      when(() => repository.getWineCount()).thenAnswer((_) async => 3);
      when(() => repository.deleteAllWines()).thenAnswer((_) async {});

      await _pumpScreen(tester, repository);

      // Les 2 nouvelles cartes backup poussent la carte de suppression en-dessous
      // du viewport de test (800×600) — on défile jusqu'à la rendre visible.
      await tester.dragUntilVisible(
        find.text('Supprimer tous les vins'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer tous les vins'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer tous les vins ?'), findsOneWidget);
      expect(find.textContaining('3 vin(s)'), findsOneWidget);

      await tester.tap(find.text('Tout supprimer'));
      await tester.pumpAndSettle();

      verify(() => repository.deleteAllWines()).called(1);
      expect(find.text('3 vin(s) supprimé(s) avec succès.'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _MockWineRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/developer',
    routes: [
      GoRoute(
        path: '/developer',
        builder: (context, state) => const DeveloperScreen(),
        routes: [
          GoRoute(
            path: 'reevaluate',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Écran réévaluation factice')),
            ),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wineRepositoryProvider.overrideWithValue(repository),
        deleteAllWinesUseCaseProvider.overrideWithValue(
          DeleteAllWinesUseCase(repository),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
