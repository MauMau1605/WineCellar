import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import 'tables/wines.dart';
import 'tables/food_categories.dart';
import 'tables/wine_food_pairings.dart';
import 'daos/wine_dao.dart';
import 'daos/food_category_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Wines, FoodCategories, WineFoodPairings],
  daos: [WineDao, FoodCategoryDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // For testing
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => AppConstants.databaseVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Seed default food categories
        await _seedFoodCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(wines, wines.location);
        }
      },
    );
  }

  /// Pre-populate food categories with common French food types
  Future<void> _seedFoodCategories() async {
    final categories = [
      FoodCategoriesCompanion.insert(
          name: 'Viande rouge', icon: const Value('🥩'), sortOrder: const Value(1)),
      FoodCategoriesCompanion.insert(
          name: 'Viande blanche', icon: const Value('🍗'), sortOrder: const Value(2)),
      FoodCategoriesCompanion.insert(
          name: 'Volaille', icon: const Value('🐔'), sortOrder: const Value(3)),
      FoodCategoriesCompanion.insert(
          name: 'Gibier', icon: const Value('🦌'), sortOrder: const Value(4)),
      FoodCategoriesCompanion.insert(
          name: 'Poisson', icon: const Value('🐟'), sortOrder: const Value(5)),
      FoodCategoriesCompanion.insert(
          name: 'Fruits de mer', icon: const Value('🦐'), sortOrder: const Value(6)),
      FoodCategoriesCompanion.insert(
          name: 'Fromage', icon: const Value('🧀'), sortOrder: const Value(7)),
      FoodCategoriesCompanion.insert(
          name: 'Charcuterie', icon: const Value('🥓'), sortOrder: const Value(8)),
      FoodCategoriesCompanion.insert(
          name: 'Pâtes / Risotto', icon: const Value('🍝'), sortOrder: const Value(9)),
      FoodCategoriesCompanion.insert(
          name: 'Pizza', icon: const Value('🍕'), sortOrder: const Value(10)),
      FoodCategoriesCompanion.insert(
          name: 'Salade', icon: const Value('🥗'), sortOrder: const Value(11)),
      FoodCategoriesCompanion.insert(
          name: 'Soupe', icon: const Value('🍲'), sortOrder: const Value(12)),
      FoodCategoriesCompanion.insert(
          name: 'Barbecue / Grillades',
          icon: const Value('🔥'),
          sortOrder: const Value(13)),
      FoodCategoriesCompanion.insert(
          name: 'Cuisine asiatique',
          icon: const Value('🥢'),
          sortOrder: const Value(14)),
      FoodCategoriesCompanion.insert(
          name: 'Cuisine épicée',
          icon: const Value('🌶️'),
          sortOrder: const Value(15)),
      FoodCategoriesCompanion.insert(
          name: 'Dessert chocolat',
          icon: const Value('🍫'),
          sortOrder: const Value(16)),
      FoodCategoriesCompanion.insert(
          name: 'Dessert fruité',
          icon: const Value('🍓'),
          sortOrder: const Value(17)),
      FoodCategoriesCompanion.insert(
          name: 'Apéritif', icon: const Value('🥂'), sortOrder: const Value(18)),
    ];

    for (final category in categories) {
      await into(foodCategories).insert(category);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConstants.databaseName));
    return NativeDatabase.createInBackground(file);
  });
}
