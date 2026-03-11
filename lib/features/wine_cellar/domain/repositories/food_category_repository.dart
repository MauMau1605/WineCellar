import '../entities/food_category_entity.dart';

/// Abstract repository for food categories
abstract class FoodCategoryRepository {
  /// Get all food categories
  Future<List<FoodCategoryEntity>> getAllCategories();

  /// Watch all food categories (reactive)
  Stream<List<FoodCategoryEntity>> watchAllCategories();

  /// Find categories matching a name (for AI auto-matching)
  Future<List<FoodCategoryEntity>> findByName(String name);

  /// Create a category if it does not exist, otherwise return existing.
  Future<FoodCategoryEntity> createOrGetCategory(String name, {String? icon});
}
