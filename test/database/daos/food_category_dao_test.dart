import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/database/app_database.dart';

void main() {
  group('FoodCategoryDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('getAllCategories et watchAllCategories ordonnent par sortOrder',
        () async {
      final initialCount = (await db.foodCategoryDao.getAllCategories()).length;
      final watch = expectLater(
        db.foodCategoryDao.watchAllCategories(),
        emitsThrough(
          predicate<List<FoodCategory>>(
            (categories) =>
                categories.length >= initialCount + 2 &&
                categories.any((category) => category.name == 'Ordre A') &&
                categories.any((category) => category.name == 'Ordre B'),
          ),
        ),
      );

      await db.into(db.foodCategories).insert(
        FoodCategoriesCompanion.insert(
          name: 'Ordre B',
          sortOrder: const Value(2001),
        ),
      );
      await db.into(db.foodCategories).insert(
        FoodCategoriesCompanion.insert(
          name: 'Ordre A',
          sortOrder: const Value(2000),
        ),
      );

      final all = await db.foodCategoryDao.getAllCategories();
      final orderAIndex = all.indexWhere((category) => category.name == 'Ordre A');
      final orderBIndex = all.indexWhere((category) => category.name == 'Ordre B');

      expect(orderAIndex, isNonNegative);
      expect(orderBIndex, greaterThan(orderAIndex));
      await watch;
    });

    test('getCategoryById et findCategoriesByName retrouvent les entrées attendues',
        () async {
      final categoryId = await db.into(db.foodCategories).insert(
        FoodCategoriesCompanion.insert(
          name: 'Accord safran unique',
          icon: const Value('saffron'),
          sortOrder: const Value(3000),
        ),
      );

      final byId = await db.foodCategoryDao.getCategoryById(categoryId);
      final byName = await db.foodCategoryDao.findCategoriesByName('safran');

      expect(byId?.name, 'Accord safran unique');
      expect(byId?.icon, 'saffron');
      expect(byName.map((category) => category.id), [categoryId]);
    });

    test('createOrGetByName trimme, ignore la casse et incrémente sortOrder',
        () async {
      final before = await db.foodCategoryDao.getAllCategories();
      final maxSortOrder = before
          .map((category) => category.sortOrder)
          .fold<int>(0, (current, value) => value > current ? value : current);

      final created = await db.foodCategoryDao.createOrGetByName(
        '  Accord umami  ',
        icon: 'umami',
      );
      final reused = await db.foodCategoryDao.createOrGetByName('accord UMAMI');

      expect(created.name, 'Accord umami');
      expect(created.icon, 'umami');
      expect(created.sortOrder, maxSortOrder + 1);
      expect(reused.id, created.id);
    });

    test('createOrGetByName rejette un nom vide', () async {
      await expectLater(
        () => db.foodCategoryDao.createOrGetByName('   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}