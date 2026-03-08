import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:csv/csv.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/database/daos/wine_dao.dart';
import 'package:wine_cellar/database/daos/food_category_dao.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_import_row.dart';
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
  Future<List<WineEntity>> getAllWines() async {
    final wines = await _wineDao.getAllWines();
    return wines.map(_mapToEntity).toList();
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
        'Localisation', 'Position cave X', 'Position cave Y',
        'IA: accords mets-vins', 'IA: boire dès', 'IA: boire jusqu\'à',
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
            w.location ?? '',
            w.cellarPositionX?.toString() ?? '',
            w.cellarPositionY?.toString() ?? '',
            w.aiSuggestedFoodPairings ? 'true' : 'false',
            w.aiSuggestedDrinkFromYear ? 'true' : 'false',
            w.aiSuggestedDrinkUntilYear ? 'true' : 'false',
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

  @override
  Future<List<CsvImportRow>> parseCsvRows(
    String csvString,
    CsvColumnMapping mapping, {
    bool hasHeader = true,
  }) async {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(csvString);

    if (rows.isEmpty) {
      return [];
    }

    final parsedRows = <CsvImportRow>[];
    final startIndex = hasHeader ? 1 : 0;

    for (var i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (_isCsvRowEmpty(row)) continue;

      final grapeValue = _readCsvValue(row, mapping.grapeVarieties);
      final grapes = grapeValue == null
          ? const <String>[]
          : grapeValue
              .split(RegExp(r'[,;/]'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();

      parsedRows.add(
        CsvImportRow(
          sourceRowNumber: i + 1,
          name: _readCsvValue(row, mapping.name),
          vintage: _parseInt(_readCsvValue(row, mapping.vintage)),
          producer: _readCsvValue(row, mapping.producer),
          appellation: _readCsvValue(row, mapping.appellation),
          quantity: _parseInt(_readCsvValue(row, mapping.quantity)),
          color: _readCsvValue(row, mapping.color),
          region: _readCsvValue(row, mapping.region),
          country: _readCsvValue(row, mapping.country),
          grapeVarieties: grapes,
          purchasePrice: _parseDouble(_readCsvValue(row, mapping.purchasePrice)),
          location: _readCsvValue(row, mapping.location),
          notes: _readCsvValue(row, mapping.notes),
        ),
      );
    }

    return parsedRows;
  }

  @override
  Future<int> importFromCsv(
    String csvString,
    CsvColumnMapping mapping, {
    bool hasHeader = true,
  }) async {
    final rows = await parseCsvRows(
      csvString,
      mapping,
      hasHeader: hasHeader,
    );

    var importedCount = 0;
    for (final row in rows) {
      final safeName = (row.name ?? '').trim();
      if (safeName.isEmpty) continue;

      await addWine(
        WineEntity(
          name: safeName,
          appellation: row.appellation,
          producer: row.producer,
          region: row.region,
          country: row.country ?? 'France',
          color: _parseColor(row.color),
          vintage: row.vintage,
          grapeVarieties: row.grapeVarieties,
          quantity: (row.quantity ?? 1) <= 0 ? 1 : row.quantity!,
          purchasePrice: row.purchasePrice,
          location: row.location,
          notes: row.notes,
          aiSuggestedFoodPairings: false,
          aiSuggestedDrinkFromYear: false,
          aiSuggestedDrinkUntilYear: false,
        ),
      );
      importedCount++;
    }

    return importedCount;
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
      aiSuggestedDrinkFromYear: dbWine.aiSuggestedDrinkFromYear,
      drinkUntilYear: dbWine.drinkUntilYear,
      aiSuggestedDrinkUntilYear: dbWine.aiSuggestedDrinkUntilYear,
      tastingNotes: dbWine.tastingNotes,
      rating: dbWine.rating,
      photoPath: dbWine.photoPath,
      aiDescription: dbWine.aiDescription,
      aiSuggestedFoodPairings: dbWine.aiSuggestedFoodPairings,
      location: dbWine.location,
      cellarPositionX: dbWine.cellarPositionX,
      cellarPositionY: dbWine.cellarPositionY,
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
      aiSuggestedDrinkFromYear: Value(entity.aiSuggestedDrinkFromYear),
      drinkUntilYear: Value(entity.drinkUntilYear),
      aiSuggestedDrinkUntilYear: Value(entity.aiSuggestedDrinkUntilYear),
      tastingNotes: Value(entity.tastingNotes),
      rating: Value(entity.rating),
      photoPath: Value(entity.photoPath),
      aiDescription: Value(entity.aiDescription),
      aiSuggestedFoodPairings: Value(entity.aiSuggestedFoodPairings),
      location: Value(entity.location),
      cellarPositionX: Value(entity.cellarPositionX),
      cellarPositionY: Value(entity.cellarPositionY),
      notes: Value(entity.notes),
    );
  }

  String? _readCsvValue(List<dynamic> row, int? columnNumber) {
    if (columnNumber == null || columnNumber <= 0) {
      return null;
    }

    final index = columnNumber - 1;
    if (index >= row.length) {
      return null;
    }

    final value = row[index].toString().trim();
    if (value.isEmpty) {
      return null;
    }

    return value;
  }

  bool _isCsvRowEmpty(List<dynamic> row) {
    for (final value in row) {
      if (value.toString().trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  int? _parseInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), ''));
  }

  double? _parseDouble(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.-]'), '');
    return double.tryParse(normalized);
  }

  WineColor _parseColor(String? rawColor) {
    final value = (rawColor ?? '').trim().toLowerCase();
    if (value.isEmpty) return WineColor.red;

    if (value.contains('blanc') || value == 'white') {
      return WineColor.white;
    }
    if (value.contains('ros') || value == 'rose') {
      return WineColor.rose;
    }
    if (value.contains('pétillant') ||
        value.contains('petillant') ||
        value.contains('effervescent') ||
        value.contains('sparkling')) {
      return WineColor.sparkling;
    }
    if (value.contains('moelleux') || value.contains('doux') || value == 'sweet') {
      return WineColor.sweet;
    }
    return WineColor.red;
  }
}
