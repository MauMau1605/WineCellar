import 'package:drift/drift.dart';
import 'wines.dart';
import 'food_categories.dart';

/// Junction table for wine-food pairings (many-to-many)
class WineFoodPairings extends Table {
  IntColumn get wineId =>
      integer().references(Wines, #id, onDelete: KeyAction.cascade)();
  IntColumn get foodCategoryId =>
      integer().references(FoodCategories, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {wineId, foodCategoryId};
}
