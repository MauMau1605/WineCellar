import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/database/app_database.dart';

void main() {
  group('WineDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('insertWineWithPairings et getWineWithPairings conservent les accords',
        () async {
      final meatId = await _insertCategory(db, 'Viande test', 10);
      final fishId = await _insertCategory(db, 'Poisson test', 5);

      final wineId = await db.wineDao.insertWineWithPairings(
        WinesCompanion.insert(
          name: 'Saint Emilion',
          color: 'red',
          quantity: const Value(3),
          producer: const Value('Domaine A'),
        ),
        [meatId, fishId],
      );

      final result = await db.wineDao.getWineWithPairings(wineId);

      expect(result, isNotNull);
      expect(result?.wine.name, 'Saint Emilion');
      expect(
        result?.foodPairings.map((pairing) => pairing.name).toList(),
        ['Poisson test', 'Viande test'],
      );
    });

    test('watchers filtrent et recherchent selon les critères attendus',
        () async {
      final meatId = await _insertCategory(db, 'Grillades test', 1);
      final redWineId = await db.wineDao.insertWineWithPairings(
        WinesCompanion.insert(
          name: 'Bordeaux',
          color: 'red',
          quantity: const Value(2),
          producer: const Value('Maison Rouge'),
        ),
        [meatId],
      );
      await db.wineDao.insertWine(
        WinesCompanion.insert(
          name: 'Chablis',
          color: 'white',
          quantity: const Value(1),
          appellation: const Value('Petit Chablis'),
        ),
      );

      await expectLater(
        db.wineDao.watchAllWines(),
        emits(
          predicate<List<Wine>>(
            (wines) =>
                wines.map((wine) => wine.name).toList().join(',') ==
                'Bordeaux,Chablis',
          ),
        ),
      );

      await expectLater(
        db.wineDao.watchWinesByColor('red'),
        emits(
          predicate<List<Wine>>(
            (wines) => wines.length == 1 && wines.single.id == redWineId,
          ),
        ),
      );

      await expectLater(
        db.wineDao.watchWinesByFoodCategory(meatId),
        emits(
          predicate<List<Wine>>(
            (wines) => wines.length == 1 && wines.single.name == 'Bordeaux',
          ),
        ),
      );

      await expectLater(
        db.wineDao.searchWines('Petit'),
        emits(
          predicate<List<Wine>>(
            (wines) => wines.length == 1 && wines.single.name == 'Chablis',
          ),
        ),
      );
    });

    test('updateWineWithPairings remplace les accords et updateQuantity borne les données stockées',
        () async {
      final oldCategoryId = await _insertCategory(db, 'Ancien accord', 1);
      final newCategoryId = await _insertCategory(db, 'Nouvel accord', 2);

      final wineId = await db.wineDao.insertWineWithPairings(
        WinesCompanion.insert(
          name: 'Cotes du Rhone',
          color: 'red',
          quantity: const Value(2),
        ),
        [oldCategoryId],
      );

      await db.wineDao.updateWineWithPairings(
        WinesCompanion(
          id: Value(wineId),
          name: const Value('Cotes du Rhone villages'),
          color: const Value('red'),
          quantity: const Value(5),
        ),
        [newCategoryId],
      );
      await db.wineDao.updateQuantity(wineId, 7);

      final wine = await db.wineDao.getWineById(wineId);
      final wineWithPairings = await db.wineDao.getWineWithPairings(wineId);

      expect(wine?.name, 'Cotes du Rhone villages');
      expect(wine?.quantity, 7);
      expect(
        wineWithPairings?.foodPairings.map((pairing) => pairing.id).toList(),
        [newCategoryId],
      );
    });

    test('getWineCount, getTotalBottles et deleteAllWines reflètent l état de la table',
        () async {
      await db.wineDao.insertWine(
        WinesCompanion.insert(
          name: 'Vin A',
          color: 'red',
          quantity: const Value(2),
        ),
      );
      await db.wineDao.insertWine(
        WinesCompanion.insert(
          name: 'Vin B',
          color: 'white',
          quantity: const Value(4),
        ),
      );

      expect(await db.wineDao.getWineCount(), 2);
      expect(await db.wineDao.getTotalBottles(), 6);

      final deleted = await db.wineDao.deleteAllWines();

      expect(deleted, 2);
      expect(await db.wineDao.getAllWines(), isEmpty);
    });
  });
}

Future<int> _insertCategory(AppDatabase db, String name, int sortOrder) {
  return db.into(db.foodCategories).insert(
    FoodCategoriesCompanion.insert(
      name: name,
      sortOrder: Value(sortOrder),
    ),
  );
}