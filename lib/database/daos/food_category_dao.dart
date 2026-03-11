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

  /// Create a category if missing, otherwise return the existing one.
  Future<FoodCategory> createOrGetByName(String name, {String? icon}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }

    final existing = await (select(foodCategories)
          ..where((c) => c.name.lower().equals(trimmedName.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) {
      return existing;
    }

    final maxSortOrderRow = await (selectOnly(foodCategories)
          ..addColumns([foodCategories.sortOrder.max()]))
        .getSingle();
    final maxSortOrder = maxSortOrderRow.read(foodCategories.sortOrder.max()) ?? 0;

    final id = await into(foodCategories).insert(
      FoodCategoriesCompanion.insert(
        name: trimmedName,
        icon: Value(icon),
        sortOrder: Value(maxSortOrder + 1),
      ),
    );

    final inserted = await getCategoryById(id);
    if (inserted == null) {
      throw StateError('Failed to create food category');
    }
    return inserted;
  }
}
