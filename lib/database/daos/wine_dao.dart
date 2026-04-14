import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/wines.dart';
import '../tables/wine_food_pairings.dart';
import '../tables/food_categories.dart';

part 'wine_dao.g.dart';

/// Data class combining a wine with its food pairings
class WineWithPairings {
  final Wine wine;
  final List<FoodCategory> foodPairings;

  WineWithPairings({required this.wine, required this.foodPairings});
}

@DriftAccessor(tables: [Wines, WineFoodPairings, FoodCategories])
class WineDao extends DatabaseAccessor<AppDatabase> with _$WineDaoMixin {
  WineDao(super.db);

  /// Watch all wines ordered by name
  Stream<List<Wine>> watchAllWines() {
    return (select(wines)..orderBy([(w) => OrderingTerm.asc(w.name)])).watch();
  }

  /// Get all wines
  Future<List<Wine>> getAllWines() {
    return (select(wines)..orderBy([(w) => OrderingTerm.asc(w.name)])).get();
  }

  /// Get a single wine by ID
  Future<Wine?> getWineById(int id) {
    return (select(wines)..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  /// Get wine with its food pairings
  Future<WineWithPairings?> getWineWithPairings(int wineId) async {
    final wine = await getWineById(wineId);
    if (wine == null) return null;

    final pairings = await _getFoodPairingsForWine(wineId);
    return WineWithPairings(wine: wine, foodPairings: pairings);
  }

  /// Watch wines filtered by color
  Stream<List<Wine>> watchWinesByColor(String color) {
    return (select(wines)
          ..where((w) => w.color.equals(color))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  /// Watch wines filtered by food category
  Stream<List<Wine>> watchWinesByFoodCategory(int foodCategoryId) {
    final query = select(wines).join([
      innerJoin(
        wineFoodPairings,
        wineFoodPairings.wineId.equalsExp(wines.id),
      ),
    ])
      ..where(wineFoodPairings.foodCategoryId.equals(foodCategoryId))
      ..orderBy([OrderingTerm.asc(wines.name)]);

    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(wines)).toList(),
        );
  }

  /// Search wines by name or appellation
  Stream<List<Wine>> searchWines(String query) {
    final pattern = '%$query%';
    return (select(wines)
          ..where((w) =>
              w.name.like(pattern) |
              w.appellation.like(pattern) |
              w.region.like(pattern) |
              w.producer.like(pattern))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  /// Insert a new wine and return its ID
  Future<int> insertWine(WinesCompanion wine) {
    return into(wines).insert(wine);
  }

  /// Insert a wine with food pairings in a transaction
  Future<int> insertWineWithPairings(
    WinesCompanion wine,
    List<int> foodCategoryIds,
  ) async {
    return transaction(() async {
      final wineId = await into(wines).insert(wine);

      for (final categoryId in foodCategoryIds) {
        await into(wineFoodPairings).insert(
          WineFoodPairingsCompanion.insert(
            wineId: wineId,
            foodCategoryId: categoryId,
          ),
        );
      }

      return wineId;
    });
  }

  /// Update an existing wine
  Future<bool> updateWine(WinesCompanion wine) {
    return update(wines).replace(
      wine.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Update wine and its food pairings
  Future<void> updateWineWithPairings(
    WinesCompanion wine,
    List<int> foodCategoryIds,
  ) async {
    await transaction(() async {
      await update(wines).replace(
        wine.copyWith(updatedAt: Value(DateTime.now())),
      );

      final wineId = wine.id.value;
      // Remove existing pairings
      await (delete(wineFoodPairings)
            ..where((p) => p.wineId.equals(wineId)))
          .go();

      // Add new pairings
      for (final categoryId in foodCategoryIds) {
        await into(wineFoodPairings).insert(
          WineFoodPairingsCompanion.insert(
            wineId: wineId,
            foodCategoryId: categoryId,
          ),
        );
      }
    });
  }

  /// Delete a wine by ID
  Future<int> deleteWineById(int id) {
    return (delete(wines)..where((w) => w.id.equals(id))).go();
  }

  /// Update quantity for a wine
  Future<void> updateQuantity(int wineId, int newQuantity) async {
    await (update(wines)..where((w) => w.id.equals(wineId))).write(
      WinesCompanion(
        quantity: Value(newQuantity),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get food pairings for a wine
  Future<List<FoodCategory>> _getFoodPairingsForWine(int wineId) async {
    final query = select(foodCategories).join([
      innerJoin(
        wineFoodPairings,
        wineFoodPairings.foodCategoryId.equalsExp(foodCategories.id),
      ),
    ])
      ..where(wineFoodPairings.wineId.equals(wineId))
      ..orderBy([OrderingTerm.asc(foodCategories.sortOrder)]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(foodCategories)).toList();
  }

  /// Get total number of wines
  Future<int> getWineCount() async {
    final count = wines.id.count();
    final query = selectOnly(wines)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Get total number of bottles
  Future<int> getTotalBottles() async {
    final sum = wines.quantity.sum();
    final query = selectOnly(wines)..addColumns([sum]);
    final result = await query.getSingle();
    return result.read(sum) ?? 0;
  }

  /// Delete all wines from the database.
  Future<int> deleteAllWines() {
    return delete(wines).go();
  }
}
