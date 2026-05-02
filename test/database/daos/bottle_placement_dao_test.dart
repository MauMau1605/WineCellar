import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/database/app_database.dart';

void main() {
  group('BottlePlacementDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('watchPlacementsByCellarId et getPlacementsByWineId joignent et ordonnent les données',
        () async {
      final cellarA = await _insertCellar(db, 'A');
      final cellarB = await _insertCellar(db, 'B');
      final wineId = await _insertWine(db, 'Bourgogne');

      final watch = expectLater(
        db.bottlePlacementDao.watchPlacementsByCellarId(cellarA),
        emitsThrough(
          predicate<List<dynamic>>(
            (placements) =>
                placements.length == 2 &&
                placements[0].placement.positionY == 0 &&
                placements[0].placement.positionX == 1 &&
                placements[1].placement.positionY == 1,
          ),
        ),
      );

      await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarA,
        positionX: 0,
        positionY: 1,
      );
      await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarA,
        positionX: 1,
        positionY: 0,
      );
      await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarB,
        positionX: 2,
        positionY: 0,
      );

      final byWine = await db.bottlePlacementDao.getPlacementsByWineId(wineId);

      expect(byWine, hasLength(3));
      expect(byWine.first.placement.cellarId, cellarA);
      expect(byWine.first.wine.name, 'Bourgogne');
      expect(byWine.last.placement.cellarId, cellarB);

      await watch;
    });

    test('isSlotOccupied et placeBottle empêchent les doublons de slot',
        () async {
      final cellarId = await _insertCellar(db, 'Occupe');
      final firstWineId = await _insertWine(db, 'Morgon');
      final secondWineId = await _insertWine(db, 'Sancerre');

      await db.bottlePlacementDao.placeBottle(
        wineId: firstWineId,
        cellarId: cellarId,
        positionX: 1,
        positionY: 1,
      );

      expect(
        await db.bottlePlacementDao.isSlotOccupied(
          cellarId: cellarId,
          positionX: 1,
          positionY: 1,
        ),
        isTrue,
      );
      await expectLater(
        () => db.bottlePlacementDao.placeBottle(
          wineId: secondWineId,
          cellarId: cellarId,
          positionX: 1,
          positionY: 1,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('getPlacedBottleCountForWine, trimPlacementsForWine et clearPlacements suppriment les bons enregistrements',
        () async {
      final cellarA = await _insertCellar(db, 'Trim A');
      final cellarB = await _insertCellar(db, 'Trim B');
      final wineId = await _insertWine(db, 'Vacqueyras');

      final firstId = await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarA,
        positionX: 0,
        positionY: 0,
      );
      final secondId = await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarA,
        positionX: 1,
        positionY: 0,
      );
      final thirdId = await db.bottlePlacementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarB,
        positionX: 0,
        positionY: 1,
      );

      expect(await db.bottlePlacementDao.getPlacedBottleCountForWine(wineId), 3);

      await db.bottlePlacementDao.trimPlacementsForWine(
        wineId: wineId,
        keepCount: 1,
      );

      final afterTrim = await db.bottlePlacementDao.getPlacementsByWineId(wineId);
      expect(afterTrim, hasLength(1));
      expect(afterTrim.single.placement.id, thirdId);

      final wineB = await _insertWine(db, 'Gigondas');
      await db.bottlePlacementDao.placeBottle(
        wineId: wineB,
        cellarId: cellarA,
        positionX: 2,
        positionY: 2,
      );

      await db.bottlePlacementDao.clearPlacementsForCellar(cellarA);
      expect(
        (await db.bottlePlacementDao.getPlacementsByWineId(wineB)).length,
        0,
      );

      await db.bottlePlacementDao.clearPlacementsForWine(wineId);
      expect(
        (await db.bottlePlacementDao.getPlacementsByWineId(wineId)).length,
        0,
      );

      await db.bottlePlacementDao.placeBottle(
        wineId: wineB,
        cellarId: cellarB,
        positionX: 2,
        positionY: 1,
      );
      expect(await db.bottlePlacementDao.clearAllPlacements(), greaterThan(0));
      expect((await db.bottlePlacementDao.getPlacementsByWineId(wineB)), isEmpty);

      expect(firstId, greaterThan(0));
      expect(secondId, greaterThan(firstId));
      expect(thirdId, greaterThan(secondId));
    });

    test('moveBottlePlacement déplace la bouteille et rejette les cas invalides',
        () async {
      final cellarId = await _insertCellar(db, 'Move');
      final wineA = await _insertWine(db, 'Cornas');
      final wineB = await _insertWine(db, 'Cassis');

      final movedId = await db.bottlePlacementDao.placeBottle(
        wineId: wineA,
        cellarId: cellarId,
        positionX: 0,
        positionY: 0,
      );
      await db.bottlePlacementDao.placeBottle(
        wineId: wineB,
        cellarId: cellarId,
        positionX: 1,
        positionY: 1,
      );

      final resultId = await db.bottlePlacementDao.moveBottlePlacement(
        placementId: movedId,
        newPositionX: 2,
        newPositionY: 2,
      );

      final updated = await db.bottlePlacementDao.getPlacementsByWineId(wineA);
      expect(resultId, movedId);
      expect(updated.single.placement.positionX, 2);
      expect(updated.single.placement.positionY, 2);

      await expectLater(
        () => db.bottlePlacementDao.moveBottlePlacement(
          placementId: movedId,
          newPositionX: 1,
          newPositionY: 1,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        () => db.bottlePlacementDao.moveBottlePlacement(
          placementId: 9999,
          newPositionX: 0,
          newPositionY: 0,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

Future<int> _insertCellar(AppDatabase db, String name) {
  return db.virtualCellarDao.insertCellar(
    VirtualCellarsCompanion.insert(name: name),
  );
}

Future<int> _insertWine(AppDatabase db, String name) {
  return db.wineDao.insertWine(
    WinesCompanion.insert(
      name: name,
      color: 'red',
    ),
  );
}