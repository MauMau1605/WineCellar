import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/database/app_database.dart';

void main() {
  group('VirtualCellarDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('watchAll et getAll ordonnent les celliers par nom', () async {
      final watch = expectLater(
        db.virtualCellarDao.watchAll(),
        emitsThrough(
          predicate<List<VirtualCellar>>(
            (cellars) =>
                cellars.map((cellar) => cellar.name).toList().join(',') ==
                'Alpha,Zeta',
          ),
        ),
      );

      await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(name: 'Zeta'),
      );
      await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(name: 'Alpha'),
      );

      final all = await db.virtualCellarDao.getAll();

      expect(all.map((cellar) => cellar.name).toList(), ['Alpha', 'Zeta']);
      await watch;
    });

    test('getById et updateCellar renvoient et modifient la ligne attendue',
        () async {
      final cellarId = await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(
          name: 'Principal',
          rows: const Value(4),
          columns: const Value(6),
          theme: const Value('stoneCave'),
        ),
      );
      final before = await db.virtualCellarDao.getById(cellarId);

      final updated = await db.virtualCellarDao.updateCellar(
        VirtualCellarsCompanion(
          id: Value(cellarId),
          name: const Value('Principal rénové'),
          rows: const Value(5),
          columns: const Value(6),
          theme: const Value('premiumCave'),
        ),
      );
      final after = await db.virtualCellarDao.getById(cellarId);

      expect(before, isNotNull);
      expect(updated, isTrue);
      expect(after?.name, 'Principal rénové');
      expect(after?.rows, 5);
      expect(after?.theme, 'premiumCave');
      expect(after?.updatedAt.isBefore(before!.updatedAt), isFalse);
    });

    test('watchWinesByCellarId, getWinesByCellarId, updateCellarPlacement et clearCellarPlacementsForCellar fonctionnent ensemble',
        () async {
      final cellarId = await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(name: 'Mur nord'),
      );
      final wineA = await _insertWine(db, 'Arbois');
      final wineB = await _insertWine(db, 'Bandol');

      final watch = expectLater(
        db.virtualCellarDao.watchWinesByCellarId(cellarId),
        emitsThrough(
          predicate<List<Wine>>(
            (wines) =>
                wines.map((wine) => wine.name).toList().join(',') ==
                'Arbois,Bandol',
          ),
        ),
      );

      await db.virtualCellarDao.updateCellarPlacement(wineA, cellarId, 1, 2);
      await db.virtualCellarDao.updateCellarPlacement(wineB, cellarId, 0, 1);

      final winesInCellar = await db.virtualCellarDao.getWinesByCellarId(cellarId);
      expect(winesInCellar.map((wine) => wine.name).toList(), ['Arbois', 'Bandol']);

      await db.virtualCellarDao.clearCellarPlacementsForCellar(cellarId);

      final clearedA = await db.wineDao.getWineById(wineA);
      final clearedB = await db.wineDao.getWineById(wineB);
      expect(clearedA?.cellarId, isNull);
      expect(clearedA?.cellarPositionX, isNull);
      expect(clearedA?.cellarPositionY, isNull);
      expect(clearedB?.cellarId, isNull);

      await watch;
    });

    test('deleteCellar supprime uniquement le cellier ciblé', () async {
      final cellarA = await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(name: 'A'),
      );
      final cellarB = await db.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(name: 'B'),
      );

      final deleted = await db.virtualCellarDao.deleteCellar(cellarA);

      expect(deleted, 1);
      expect(await db.virtualCellarDao.getById(cellarA), isNull);
      expect(await db.virtualCellarDao.getById(cellarB), isNotNull);
    });
  });
}

Future<int> _insertWine(AppDatabase db, String name) {
  return db.wineDao.insertWine(
    WinesCompanion.insert(
      name: name,
      color: 'red',
    ),
  );
}