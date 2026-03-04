import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:csv/csv.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/database/daos/wine_dao.dart';
import 'package:wine_cellar/database/daos/food_category_dao.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Concrete implementation of WineRepository using Drift
class WineRepositoryImpl implements WineRepository {
  final WineDao _wineDao;
  // Will be used for food pairing features
  // ignore: unused_field
  final FoodCategoryDao _foodCategoryDao;

  WineRepositoryImpl(this._wineDao, this._foodCategoryDao);

  @override
  Stream<List<WineEntity>> watchAllWines() {
    return _wineDao.watchAllWines().map(
          (wines) => wines.map(_mapToEntity).toList(),
        );
  }

  @override
  Stream<List<WineEntity>> watchFilteredWines(WineFilter filter) {
    if (filter.isEmpty) return watchAllWines();

    // For text search
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      return _wineDao.searchWines(filter.searchQuery!).map(
            (wines) => wines.map(_mapToEntity).toList(),
          );
    }

    // For color filter
    if (filter.color != null) {
      return _wineDao.watchWinesByColor(filter.color!.name).map(
            (wines) => wines.map(_mapToEntity).toList(),
          );
    }

    // For food category filter
    if (filter.foodCategoryId != null) {
      return _wineDao.watchWinesByFoodCategory(filter.foodCategoryId!).map(
            (wines) => wines.map(_mapToEntity).toList(),
          );
    }

    // For maturity filter - we need to filter in-memory
    if (filter.maturity != null) {
      return _wineDao.watchAllWines().map(
            (wines) => wines
                .map(_mapToEntity)
                .where((w) => w.maturity == filter.maturity)
                .toList(),
          );
    }

    return watchAllWines();
  }

  @override
  Future<WineEntity?> getWineById(int id) async {
    final result = await _wineDao.getWineWithPairings(id);
    if (result == null) return null;

    return _mapToEntity(result.wine).copyWith(
      foodCategoryIds: result.foodPairings.map((p) => p.id).toList(),
    );
  }

  @override
  Future<int> addWine(WineEntity wine) async {
    final companion = _mapToCompanion(wine);
    return _wineDao.insertWineWithPairings(companion, wine.foodCategoryIds);
  }

  @override
  Future<void> updateWine(WineEntity wine) async {
    if (wine.id == null) throw ArgumentError('Wine ID cannot be null for update');
    final companion = _mapToCompanion(wine).copyWith(id: Value(wine.id!));
    await _wineDao.updateWineWithPairings(companion, wine.foodCategoryIds);
  }

  @override
  Future<void> deleteWine(int id) async {
    await _wineDao.deleteWineById(id);
  }

  @override
  Future<void> updateQuantity(int wineId, int quantity) async {
    await _wineDao.updateQuantity(wineId, quantity);
  }

  @override
  Future<int> getWineCount() => _wineDao.getWineCount();

  @override
  Future<int> getTotalBottles() => _wineDao.getTotalBottles();

  @override
  Future<String> exportToJson() async {
    final wines = await _wineDao.getAllWines();
    final entities = wines.map(_mapToEntity).toList();
    final jsonList = entities.map((w) => w.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'version': 1,
      'wines': jsonList,
    });
  }

  @override
  Future<String> exportToCsv() async {
    final wines = await _wineDao.getAllWines();
    final entities = wines.map(_mapToEntity).toList();

    final rows = <List<dynamic>>[
      // Header
      [
        'Nom', 'Appellation', 'Producteur', 'Région', 'Pays', 'Couleur',
        'Millésime', 'Cépages', 'Quantité', 'Prix achat',
        'Boire à partir de', 'Boire jusqu\'à', 'Notes', 'Note (/5)',
      ],
      // Data rows
      ...entities.map((w) => [
            w.name,
            w.appellation ?? '',
            w.producer ?? '',
            w.region ?? '',
            w.country,
            w.color.label,
            w.vintage?.toString() ?? '',
            w.grapeVarieties.join(', '),
            w.quantity,
            w.purchasePrice?.toStringAsFixed(2) ?? '',
            w.drinkFromYear?.toString() ?? '',
            w.drinkUntilYear?.toString() ?? '',
            w.tastingNotes ?? '',
            w.rating?.toString() ?? '',
          ]),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  @override
  Future<int> importFromJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final winesList = data['wines'] as List<dynamic>;
    int count = 0;

    for (final wineJson in winesList) {
      final entity = WineEntity.fromJson(wineJson as Map<String, dynamic>);
      await addWine(entity);
      count++;
    }

    return count;
  }

  // ---- Mapping helpers ----

  WineEntity _mapToEntity(Wine dbWine) {
    return WineEntity(
      id: dbWine.id,
      name: dbWine.name,
      appellation: dbWine.appellation,
      producer: dbWine.producer,
      region: dbWine.region,
      country: dbWine.country,
      color: WineColor.values.firstWhere(
        (c) => c.name == dbWine.color,
        orElse: () => WineColor.red,
      ),
      vintage: dbWine.vintage,
      grapeVarieties: WineEntity.parseGrapeVarieties(dbWine.grapeVarieties),
      quantity: dbWine.quantity,
      purchasePrice: dbWine.purchasePrice,
      purchaseDate: dbWine.purchaseDate,
      drinkFromYear: dbWine.drinkFromYear,
      drinkUntilYear: dbWine.drinkUntilYear,
      tastingNotes: dbWine.tastingNotes,
      rating: dbWine.rating,
      photoPath: dbWine.photoPath,
      aiDescription: dbWine.aiDescription,
      notes: dbWine.notes,
      createdAt: dbWine.createdAt,
      updatedAt: dbWine.updatedAt,
    );
  }

  WinesCompanion _mapToCompanion(WineEntity entity) {
    return WinesCompanion(
      name: Value(entity.name),
      appellation: Value(entity.appellation),
      producer: Value(entity.producer),
      region: Value(entity.region),
      country: Value(entity.country),
      color: Value(entity.color.name),
      vintage: Value(entity.vintage),
      grapeVarieties: Value(entity.grapeVarietiesJson),
      quantity: Value(entity.quantity),
      purchasePrice: Value(entity.purchasePrice),
      purchaseDate: Value(entity.purchaseDate),
      drinkFromYear: Value(entity.drinkFromYear),
      drinkUntilYear: Value(entity.drinkUntilYear),
      tastingNotes: Value(entity.tastingNotes),
      rating: Value(entity.rating),
      photoPath: Value(entity.photoPath),
      aiDescription: Value(entity.aiDescription),
      notes: Value(entity.notes),
    );
  }
}
