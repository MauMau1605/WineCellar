import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/virtual_cellar_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/cellar_cell_position.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

void main() {
  group('VirtualCellarRepositoryImpl', () {
    late AppDatabase db;
    late VirtualCellarRepositoryImpl repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = VirtualCellarRepositoryImpl(
        db.virtualCellarDao,
        db.bottlePlacementDao,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('crée, charge et ordonne les celliers en mappant thème et cases vides',
        () async {
      final alphaId = await repository.create(
        VirtualCellarEntity(
          name: 'Alpha',
          rows: 4,
          columns: 5,
          emptyCells: {
            CellarCellPosition(row: 1, col: 2),
            CellarCellPosition(row: 3, col: 4),
          },
          theme: VirtualCellarTheme.stoneCave,
        ),
      );
      final betaId = await repository.create(
        const VirtualCellarEntity(
          name: 'Beta',
          rows: 2,
          columns: 3,
          theme: VirtualCellarTheme.premiumCave,
        ),
      );

      expect(alphaId.isRight(), isTrue);
      expect(betaId.isRight(), isTrue);

      final allResult = await repository.getAll();
      expect(allResult.isRight(), isTrue);

      final cellars = allResult.getOrElse((_) => const []);
      expect(cellars.map((cellar) => cellar.name).toList(), ['Alpha', 'Beta']);
      expect(cellars.first.theme, VirtualCellarTheme.stoneCave);
      expect(
        cellars.first.emptyCells,
        {
          const CellarCellPosition(row: 1, col: 2),
          const CellarCellPosition(row: 3, col: 4),
        },
      );

      final byIdResult = await repository.getById(alphaId.getOrElse((_) => -1));
      expect(byIdResult.isRight(), isTrue);
      final alpha = byIdResult.getOrElse((_) => null);
      expect(alpha?.name, 'Alpha');
      expect(alpha?.rows, 4);
      expect(alpha?.columns, 5);
      expect(alpha?.theme, VirtualCellarTheme.stoneCave);
      expect(alpha?.emptyCellsCount, 2);
    });

    test('watchAll émet les celliers mappés', () async {
      final expectation = expectLater(
        repository.watchAll(),
        emitsThrough(
          predicate<List<VirtualCellarEntity>>(
            (cellars) =>
                cellars.length == 1 && cellars.single.name == 'Atelier',
          ),
        ),
      );

      final result = await repository.create(
        const VirtualCellarEntity(
          name: 'Atelier',
          rows: 3,
          columns: 6,
          theme: VirtualCellarTheme.garageIndustrial,
        ),
      );

      expect(result.isRight(), isTrue);
      await expectation;
    });

    test('met à jour un cellier existant et rejette un id manquant', () async {
      final createResult = await repository.create(
        const VirtualCellarEntity(name: 'Nord', rows: 2, columns: 2),
      );
      final cellarId = createResult.getOrElse((_) => -1);

      final updateResult = await repository.update(
        const VirtualCellarEntity(
          id: 1,
          name: 'Nord rénové',
          rows: 5,
          columns: 4,
          theme: VirtualCellarTheme.premiumCave,
        ).copyWith(id: cellarId),
      );

      expect(updateResult.isRight(), isTrue);

      final updatedRow = await db.virtualCellarDao.getById(cellarId);
      expect(updatedRow?.name, 'Nord rénové');
      expect(updatedRow?.rows, 5);
      expect(updatedRow?.columns, 4);
      expect(updatedRow?.theme, VirtualCellarTheme.premiumCave.storageValue);

      final missingIdResult = await repository.update(
        const VirtualCellarEntity(name: 'Sans id', rows: 1, columns: 1),
      );
      expect(missingIdResult.isLeft(), isTrue);
      missingIdResult.fold(
        (failure) => expect(
          failure,
          const CacheFailure('ID du cellier manquant pour la mise à jour.'),
        ),
        (_) => fail('Doit retourner un CacheFailure'),
      );
    });

    test('supprime un cellier en effaçant ses placements', () async {
      final cellarId = await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(
          name: 'Cellier test',
          rows: const Value(3),
          columns: const Value(3),
        ),
      );
      final wineId = await _insertWine(db, name: 'Syrah', quantity: 2);
      await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarId,
        positionX: 0,
        positionY: 0,
      );

      final deleteResult = await repository.delete(cellarId);

      expect(deleteResult.isRight(), isTrue);
      expect(await db.virtualCellarDao.getById(cellarId), isNull);
      expect(
        await db.bottlePlacementDao.getPlacementsByWineId(wineId),
        isEmpty,
      );
      expect(await db.wineDao.getWineById(wineId), isNotNull);
    });

    test('retourne les vins uniques d un cellier et expose placements et compteurs',
        () async {
      final cellarId = await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(
          name: 'Mur sud',
          rows: const Value(4),
          columns: const Value(4),
        ),
      );
      final wineId = await _insertWine(db, name: 'Merlot', quantity: 3);

      final winesWatch = expectLater(
        repository.watchWinesByCellarId(cellarId),
        emitsThrough(
          predicate<List<dynamic>>(
            (wines) => wines.length == 1 && wines.single.name == 'Merlot',
          ),
        ),
      );
      final placementsWatch = expectLater(
        repository.watchPlacementsByCellarId(cellarId),
        emitsThrough(
          predicate<List<dynamic>>(
            (placements) =>
                placements.length == 2 && placements.first.wine.name == 'Merlot',
          ),
        ),
      );

      await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarId,
        positionX: 1,
        positionY: 0,
      );
      await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarId,
        positionX: 2,
        positionY: 1,
      );

      final winesResult = await repository.getWinesByCellarId(cellarId);
      final placementsResult = await repository.getPlacementsByWineId(wineId);
      final countResult = await repository.getPlacedBottleCount(wineId);

      expect(winesResult.isRight(), isTrue);
      expect(winesResult.getOrElse((_) => const []).length, 1);
      expect(winesResult.getOrElse((_) => const []).single.name, 'Merlot');
      expect(placementsResult.isRight(), isTrue);
      expect(placementsResult.getOrElse((_) => const []).length, 2);
      expect(countResult.getOrElse((_) => -1), 2);

      await winesWatch;
      await placementsWatch;
    });

    test('place, déplace, retaille et retire des placements', () async {
      final cellarId = await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(
          name: 'Arrière cave',
          rows: const Value(5),
          columns: const Value(5),
        ),
      );
      final wineId = await _insertWine(db, name: 'Grenache', quantity: 3);

      final firstPlacement = await repository.placeWine(
        wineId,
        cellarId: cellarId,
        positionX: 0,
        positionY: 0,
      );
      final secondPlacement = await repository.placeWine(
        wineId,
        cellarId: cellarId,
        positionX: 1,
        positionY: 0,
      );
      final thirdPlacement = await repository.placeWine(
        wineId,
        cellarId: cellarId,
        positionX: 2,
        positionY: 0,
      );

      expect(firstPlacement.isRight(), isTrue);
      expect(secondPlacement.isRight(), isTrue);
      expect(thirdPlacement.isRight(), isTrue);

      final placementsBeforeTrim = await repository.getPlacementsByWineId(wineId);
      final lastPlacementId = placementsBeforeTrim.getOrElse((_) => const []).last.id;

      final moveResult = await repository.moveBottleInCellar(
        placementId: lastPlacementId,
        newPositionX: 2,
        newPositionY: 2,
      );
      expect(moveResult.isRight(), isTrue);

      final trimResult = await repository.trimPlacementsForWine(
        wineId: wineId,
        maxPlacements: 1,
      );
      expect(trimResult.isRight(), isTrue);

      final placementsAfterTrim = await repository.getPlacementsByWineId(wineId);
      expect(placementsAfterTrim.getOrElse((_) => const []).length, 1);

      final remainingPlacementId =
          placementsAfterTrim.getOrElse((_) => const []).single.id;
      final removeResult = await repository.removePlacement(remainingPlacementId);
      expect(removeResult.isRight(), isTrue);
      final countResult = await repository.getPlacedBottleCount(wineId);
      expect(countResult.isRight(), isTrue);
      expect(countResult.getOrElse((_) => -1), 0);
    });

    test('retourne un CacheFailure si un emplacement est déjà occupé', () async {
      final cellarId = await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(
          name: 'Coin test',
          rows: const Value(2),
          columns: const Value(2),
        ),
      );
      final firstWineId = await _insertWine(db, name: 'Pinot noir');
      final secondWineId = await _insertWine(db, name: 'Chenin');

      final firstResult = await repository.placeWine(
        firstWineId,
        cellarId: cellarId,
        positionX: 1,
        positionY: 1,
      );
      final duplicateResult = await repository.placeWine(
        secondWineId,
        cellarId: cellarId,
        positionX: 1,
        positionY: 1,
      );

      expect(firstResult.isRight(), isTrue);
      expect(duplicateResult.isLeft(), isTrue);
      duplicateResult.fold(
        (failure) {
          expect(failure, isA<CacheFailure>());
          expect(failure.message, 'Impossible de placer la bouteille.');
        },
        (_) => fail('Doit retourner un CacheFailure'),
      );
    });
  });
}

Future<int> _insertWine(
  AppDatabase db, {
  required String name,
  WineColor color = WineColor.red,
  int quantity = 1,
}) {
  return db.wineDao.insertWine(
    WinesCompanion.insert(
      name: name,
      color: color.name,
      quantity: Value(quantity),
    ),
  );
}