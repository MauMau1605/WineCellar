import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/screens/virtual_cellar_detail_screen.dart';

class _MockWineRepository extends Mock implements WineRepository {}

class _MockVirtualCellarRepository extends Mock
    implements VirtualCellarRepository {}

void main() {
  group('VirtualCellarDetailScreen', () {
    late _MockWineRepository wineRepository;
    late _MockVirtualCellarRepository virtualCellarRepository;

    setUp(() {
      wineRepository = _MockWineRepository();
      virtualCellarRepository = _MockVirtualCellarRepository();

      when(
        () => virtualCellarRepository.watchPlacementsByCellarId(any()),
      ).thenAnswer((_) => Stream.value(const <BottlePlacementEntity>[]));
    });

    testWidgets('affiche un etat introuvable quand le cellier est absent', (
      tester,
    ) async {
      when(
        () => virtualCellarRepository.getById(21),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wineRepositoryProvider.overrideWithValue(wineRepository),
            virtualCellarRepositoryProvider.overrideWithValue(
              virtualCellarRepository,
            ),
          ],
          child: const MaterialApp(
            home: VirtualCellarDetailScreen(cellarId: 21),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cellier introuvable'), findsOneWidget);
      expect(find.text('Ce cellier n\'existe plus.'), findsOneWidget);
    });

    testWidgets(
      'signale quand toutes les bouteilles preselectionnees sont deja placees',
      (tester) async {
        const cellar = VirtualCellarEntity(
          id: 5,
          name: 'Cellier principal',
          rows: 5,
          columns: 5,
        );
        const wine = WineEntity(
          id: 7,
          name: 'Chablis Test',
          country: 'France',
          color: WineColor.white,
          vintage: 2020,
          quantity: 2,
        );

        when(
          () => virtualCellarRepository.getById(5),
        ).thenAnswer((_) async => const Right(cellar));
        when(() => wineRepository.getWineById(7)).thenAnswer((_) async => wine);
        when(
          () => virtualCellarRepository.getPlacedBottleCount(7),
        ).thenAnswer((_) async => const Right(2));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              wineRepositoryProvider.overrideWithValue(wineRepository),
              virtualCellarRepositoryProvider.overrideWithValue(
                virtualCellarRepository,
              ),
            ],
            child: const MaterialApp(
              home: VirtualCellarDetailScreen(
                cellarId: 5,
                preSelectedWineId: 7,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.text('Cellier principal'), findsWidgets);
        expect(
          find.text(
            'Toutes les bouteilles de Chablis Test 2020 sont déjà placées.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
