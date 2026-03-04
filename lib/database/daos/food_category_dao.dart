import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/food_categories.dart';

part 'food_category_dao.g.dart';

@DriftAccessor(tables: [FoodCategories])
class FoodCategoryDao extends DatabaseAccessor<AppDatabase>
    with _$FoodCategoryDaoMixin {
  FoodCategoryDao(super.db);

  /// Get all food categories ordered by sortOrder
  Future<List<FoodCategory>> getAllCategories() {
    return (select(foodCategories)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  /// Watch all food categories
  Stream<List<FoodCategory>> watchAllCategories() {
    return (select(foodCategories)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  /// Get a category by ID
  Future<FoodCategory?> getCategoryById(int id) {
    return (select(foodCategories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Find categories by name (for AI matching)
  Future<List<FoodCategory>> findCategoriesByName(String name) {
    return (select(foodCategories)
          ..where((c) => c.name.like('%$name%')))
        .get();
  }
}
