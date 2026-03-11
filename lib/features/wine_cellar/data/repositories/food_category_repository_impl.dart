import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/database/daos/food_category_dao.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/food_category_repository.dart';

/// Concrete implementation of FoodCategoryRepository using Drift
class FoodCategoryRepositoryImpl implements FoodCategoryRepository {
  final FoodCategoryDao _dao;

  FoodCategoryRepositoryImpl(this._dao);

  @override
  Future<List<FoodCategoryEntity>> getAllCategories() async {
    final categories = await _dao.getAllCategories();
    return categories.map(_mapToEntity).toList();
  }

  @override
  Stream<List<FoodCategoryEntity>> watchAllCategories() {
    return _dao.watchAllCategories().map(
          (categories) => categories.map(_mapToEntity).toList(),
        );
  }

  @override
  Future<List<FoodCategoryEntity>> findByName(String name) async {
    final categories = await _dao.findCategoriesByName(name);
    return categories.map(_mapToEntity).toList();
  }

  @override
  Future<FoodCategoryEntity> createOrGetCategory(String name, {String? icon}) async {
    final category = await _dao.createOrGetByName(name, icon: icon);
    return _mapToEntity(category);
  }

  FoodCategoryEntity _mapToEntity(FoodCategory db) {
    return FoodCategoryEntity(
      id: db.id,
      name: db.name,
      icon: db.icon,
      sortOrder: db.sortOrder,
    );
  }
}
