import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/food_category_repository_impl.dart';

void main() {
  group('FoodCategoryRepositoryImpl', () {
    late AppDatabase db;
    late FoodCategoryRepositoryImpl repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = FoodCategoryRepositoryImpl(db.foodCategoryDao);
    });

    tearDown(() async {
      await db.close();
    });

    test('createOrGetCategory crée puis réutilise une catégorie existante',
        () async {
      final created = await repository.createOrGetCategory(
        '  Accords truffe  ',
        icon: 'truffle',
      );
      final reused = await repository.createOrGetCategory('accords truffe');

      expect(created.name, 'Accords truffe');
      expect(created.icon, 'truffle');
      expect(reused.id, created.id);
      expect(reused.name, created.name);
      expect(reused.icon, created.icon);
    });

    test('getAllCategories et findByName retournent les entités mappées',
        () async {
      final cheese = await repository.createOrGetCategory(
        'Plateau de fromages',
        icon: 'cheese',
      );
      await repository.createOrGetCategory('Desserts aux fruits', icon: 'fruit');

      final allCategories = await repository.getAllCategories();
      final found = await repository.findByName('fromages');

      expect(
        allCategories.any((category) => category.id == cheese.id),
        isTrue,
      );
      final cheeseCategory = allCategories.firstWhere(
        (category) => category.id == cheese.id,
      );
      expect(cheeseCategory.name, 'Plateau de fromages');
      expect(cheeseCategory.icon, 'cheese');
      expect(found.map((category) => category.name), ['Plateau de fromages']);
    });

    test('watchAllCategories émet la catégorie créée', () async {
      final expectation = expectLater(
        repository.watchAllCategories(),
        emitsThrough(
          predicate<List<dynamic>>(
            (categories) => categories.any(
              (category) => category.name == 'Cuisine végétale',
            ),
          ),
        ),
      );

      await repository.createOrGetCategory('Cuisine végétale', icon: 'leaf');

      await expectation;
    });
  });
}