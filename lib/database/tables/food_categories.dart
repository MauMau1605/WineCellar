import 'package:drift/drift.dart';

/// Food categories for wine-food pairings
class FoodCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get icon => text().nullable()(); // emoji or icon name
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
