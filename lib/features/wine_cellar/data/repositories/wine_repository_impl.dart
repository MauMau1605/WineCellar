import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:csv/csv.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/database/daos/bottle_placement_dao.dart';
import 'package:wine_cellar/database/daos/wine_dao.dart';
import 'package:wine_cellar/database/daos/food_category_dao.dart';
import 'package:wine_cellar/database/daos/virtual_cellar_dao.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_import_row.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Concrete implementation of WineRepository using Drift
class WineRepositoryImpl implements WineRepository {
  final WineDao _wineDao;
  // Will be used for food pairing features
  // ignore: unused_field
  final FoodCategoryDao _foodCategoryDao;
  final VirtualCellarDao _virtualCellarDao;
  final BottlePlacementDao _bottlePlacementDao;

  WineRepositoryImpl(
    this._wineDao,
    this._foodCategoryDao,
    this._virtualCellarDao,
    this._bottlePlacementDao,
  );

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
      return _wineDao
          .searchWines(filter.searchQuery!)
          .map((wines) => wines.map(_mapToEntity).toList());
    }

    // For color filter
    if (filter.color != null) {
      return _wineDao
          .watchWinesByColor(filter.color!.name)
          .map((wines) => wines.map(_mapToEntity).toList());
    }

    // For food category filter
    if (filter.foodCategoryId != null) {
      return _wineDao
          .watchWinesByFoodCategory(filter.foodCategoryId!)
          .map((wines) => wines.map(_mapToEntity).toList());
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

    return _mapToEntity(
      result.wine,
    ).copyWith(foodCategoryIds: result.foodPairings.map((p) => p.id).toList());
  }

  @override
  Future<int> addWine(WineEntity wine) async {
    final companion = _mapToCompanion(wine);
    return _wineDao.insertWineWithPairings(companion, wine.foodCategoryIds);
  }

  @override
  Future<void> updateWine(WineEntity wine) async {
    if (wine.id == null) {
      throw ArgumentError('Wine ID cannot be null for update');
    }
    final companion = _mapToCompanion(wine).copyWith(id: Value(wine.id!));
    await _wineDao.updateWineWithPairings(companion, wine.foodCategoryIds);
  }

  @override
  Future<void> deleteWine(int id) async {
    await _bottlePlacementDao.clearPlacementsForWine(id);
    await _wineDao.deleteWineById(id);
  }

  @override
  Future<void> updateQuantity(int wineId, int quantity) async {
    final safeQty = quantity < 0 ? 0 : quantity;
    await _wineDao.updateQuantity(wineId, safeQty);
    await _bottlePlacementDao.trimPlacementsForWine(
      wineId: wineId,
      keepCount: safeQty,
    );
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
    final cellars = await _virtualCellarDao.getAll();
    final placements = await _wineDao.db
        .select(_wineDao.db.bottlePlacements)
        .get();
    final entities = wines.map(_mapToEntity).toList();
    final jsonList = entities.map((w) => w.toJson()).toList();
    final cellarList = cellars.map(_mapCellarToJson).toList();
    final placementList = placements.map(_mapPlacementToJson).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'version': 2,
      'snapshotType': 'full_cellar',
      'virtualCellars': cellarList,
      'bottlePlacements': placementList,
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
        'Nom',
        'Appellation',
        'Producteur',
        'Région',
        'Pays',
        'Couleur',
        'Millésime',
        'Cépages',
        'Quantité',
        'Prix achat',
        'Boire à partir de',
        'Boire jusqu\'à',
        'Notes',
        'Note (/5)',
        'Localisation',
        'Position cave X',
        'Position cave Y',
        'IA: accords mets-vins',
        'IA: boire dès',
        'IA: boire jusqu\'à',
      ],
      // Data rows
      ...entities.map(
        (w) => [
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
        ],
      ),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  @override
  Future<int> importFromJson(String jsonString) async {
    final decoded = jsonDecode(jsonString);

    Map<String, dynamic> data;
    List<dynamic> winesList;

    // Legacy compatibility: allow a root-level array of wines.
    if (decoded is List<dynamic>) {
      data = const <String, dynamic>{};
      winesList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      data = decoded;
      winesList = (data['wines'] as List<dynamic>? ?? const []);
    } else {
      throw const FormatException('Format JSON non supporté pour l\'import.');
    }

    final cellarsList = (data['virtualCellars'] as List<dynamic>? ?? const []);
    final placementsList =
        (data['bottlePlacements'] as List<dynamic>? ?? const []);
    final isFullSnapshot =
        data['snapshotType'] == 'full_cellar' ||
        data.containsKey('virtualCellars');

    if (isFullSnapshot) {
      return _restoreSnapshotFromJson(
        winesList: winesList,
        cellarsList: cellarsList,
        placementsList: placementsList,
      );
    }

    int count = 0;

    for (final wineJson in winesList) {
      final parsedWine = _parseWineFromJsonCompat(wineJson);
      if (parsedWine == null) continue;

      final entity = _sanitizeImportedWine(parsedWine);
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
          purchasePrice: _parseDouble(
            _readCsvValue(row, mapping.purchasePrice),
          ),
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
    final rows = await parseCsvRows(csvString, mapping, hasHeader: hasHeader);

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

  Future<int> _restoreSnapshotFromJson({
    required List<dynamic> winesList,
    required List<dynamic> cellarsList,
    required List<dynamic> placementsList,
  }) async {
    final db = _wineDao.db;

    return db.transaction(() async {
      await db.delete(db.wineFoodPairings).go();
      await db.delete(db.bottlePlacements).go();
      await db.delete(db.wines).go();
      await db.delete(db.virtualCellars).go();

      final cellarIdMap = <int, int>{};

      for (final cellarJson in cellarsList) {
        final cellar = _mapCellarFromJsonCompat(cellarJson);
        if (cellar == null) continue;

        final newId = await _virtualCellarDao.insertCellar(
          VirtualCellarsCompanion.insert(
            name: cellar.name,
            rows: Value(cellar.rows),
            columns: Value(cellar.columns),
            emptyCells: Value(cellar.emptyCellsStorage),
            createdAt: Value(cellar.createdAt ?? DateTime.now()),
            updatedAt: Value(cellar.updatedAt ?? DateTime.now()),
          ),
        );

        if (cellar.id != null) {
          cellarIdMap[cellar.id!] = newId;
        }
      }

      final wineIdMap = <int, int>{};
      var importedCount = 0;
      for (final wineJson in winesList) {
        final importedWine = _parseWineFromJsonCompat(wineJson);
        if (importedWine == null) continue;

        final restoredWine = importedWine.copyWith(
          cellarId: null,
          cellarPositionX: null,
          cellarPositionY: null,
        );

        final newWineId = await _wineDao.insertWineWithPairings(
          _mapToCompanion(restoredWine),
          restoredWine.foodCategoryIds,
        );
        if (importedWine.id != null) {
          wineIdMap[importedWine.id!] = newWineId;
        }
        importedCount++;
      }

      for (final placementJson in placementsList) {
        final placement = _mapPlacementFromJsonCompat(placementJson);
        if (placement == null) continue;

        final remappedWineId = wineIdMap[placement.wineId];
        final remappedCellarId = cellarIdMap[placement.cellarId];
        if (remappedWineId == null || remappedCellarId == null) {
          continue;
        }

        final occupied = await _bottlePlacementDao.isSlotOccupied(
          cellarId: remappedCellarId,
          positionX: placement.positionX,
          positionY: placement.positionY,
        );
        if (occupied) continue;

        await _bottlePlacementDao.placeBottle(
          wineId: remappedWineId,
          cellarId: remappedCellarId,
          positionX: placement.positionX,
          positionY: placement.positionY,
        );
      }

      return importedCount;
    });
  }

  WineEntity _sanitizeImportedWine(WineEntity entity) {
    return WineEntity(
      id: entity.id,
      name: entity.name,
      appellation: entity.appellation,
      producer: entity.producer,
      region: entity.region,
      country: entity.country,
      color: entity.color,
      vintage: entity.vintage,
      grapeVarieties: entity.grapeVarieties,
      quantity: entity.quantity,
      purchasePrice: entity.purchasePrice,
      purchaseDate: entity.purchaseDate,
      drinkFromYear: entity.drinkFromYear,
      aiSuggestedDrinkFromYear: entity.aiSuggestedDrinkFromYear,
      drinkUntilYear: entity.drinkUntilYear,
      aiSuggestedDrinkUntilYear: entity.aiSuggestedDrinkUntilYear,
      tastingNotes: entity.tastingNotes,
      rating: entity.rating,
      photoPath: entity.photoPath,
      aiDescription: entity.aiDescription,
      aiSuggestedFoodPairings: entity.aiSuggestedFoodPairings,
      location: entity.location,
      cellarId: null,
      cellarPositionX: null,
      cellarPositionY: null,
      notes: entity.notes,
      foodCategoryIds: entity.foodCategoryIds,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> _mapCellarToJson(VirtualCellar row) {
    return {
      'id': row.id,
      'name': row.name,
      'rows': row.rows,
      'columns': row.columns,
      'emptyCells': row.emptyCells,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _mapPlacementToJson(BottlePlacement row) {
    return {
      'id': row.id,
      'wineId': row.wineId,
      'cellarId': row.cellarId,
      'positionX': row.positionX,
      'positionY': row.positionY,
      'createdAt': row.createdAt.toIso8601String(),
    };
  }

  BottlePlacement? _mapPlacementFromJsonCompat(dynamic rawJson) {
    if (rawJson is! Map<String, dynamic>) return null;

    final wineId = _asInt(rawJson['wineId']);
    final cellarId = _asInt(rawJson['cellarId']);
    final positionX = _asInt(rawJson['positionX']);
    final positionY = _asInt(rawJson['positionY']);
    if (wineId == null ||
        cellarId == null ||
        positionX == null ||
        positionY == null) {
      return null;
    }

    return BottlePlacement(
      id: _asInt(rawJson['id']) ?? 0,
      wineId: wineId,
      cellarId: cellarId,
      positionX: positionX,
      positionY: positionY,
      createdAt: _asDateTime(rawJson['createdAt']) ?? DateTime.now(),
    );
  }

  VirtualCellarEntity? _mapCellarFromJsonCompat(dynamic rawJson) {
    if (rawJson is! Map<String, dynamic>) return null;

    final name =
        _asString(rawJson['name']) ?? _asString(rawJson['nom']) ?? 'Cellier';

    return VirtualCellarEntity(
      id: _asInt(rawJson['id']),
      name: name,
      rows: _asInt(rawJson['rows']) ?? 5,
      columns: _asInt(rawJson['columns']) ?? 5,
      emptyCells: VirtualCellarEntity.parseEmptyCells(
        _asString(rawJson['emptyCells']),
      ),
      createdAt: _asDateTime(rawJson['createdAt']),
      updatedAt: _asDateTime(rawJson['updatedAt']),
    );
  }

  WineEntity? _parseWineFromJsonCompat(dynamic rawJson) {
    if (rawJson is! Map<String, dynamic>) return null;

    final name = _asString(rawJson['name']) ?? _asString(rawJson['nom']);
    if (name == null) return null;

    final quantity = _asInt(rawJson['quantity']) ?? 1;

    return WineEntity(
      id: _asInt(rawJson['id']),
      name: name,
      appellation: _asString(rawJson['appellation']),
      producer:
          _asString(rawJson['producer']) ?? _asString(rawJson['producteur']),
      region: _asString(rawJson['region']),
      country:
          _asString(rawJson['country']) ??
          _asString(rawJson['pays']) ??
          'France',
      color: _parseColor(
        _asString(rawJson['color']) ?? _asString(rawJson['couleur']),
      ),
      vintage: _asInt(rawJson['vintage']) ?? _asInt(rawJson['millesime']),
      grapeVarieties: _asStringList(rawJson['grapeVarieties']).isNotEmpty
          ? _asStringList(rawJson['grapeVarieties'])
          : _asStringList(rawJson['cepages']),
      quantity: quantity <= 0 ? 1 : quantity,
      purchasePrice:
          _asDouble(rawJson['purchasePrice']) ??
          _asDouble(rawJson['prixAchat']),
      purchaseDate: _asDateTime(rawJson['purchaseDate']),
      drinkFromYear:
          _asInt(rawJson['drinkFromYear']) ?? _asInt(rawJson['boireAPartirDe']),
      aiSuggestedDrinkFromYear: _asBool(rawJson['aiSuggestedDrinkFromYear']),
      drinkUntilYear:
          _asInt(rawJson['drinkUntilYear']) ?? _asInt(rawJson['boireJusqua']),
      aiSuggestedDrinkUntilYear: _asBool(rawJson['aiSuggestedDrinkUntilYear']),
      tastingNotes:
          _asString(rawJson['tastingNotes']) ??
          _asString(rawJson['notesDegustation']),
      rating: _asInt(rawJson['rating']),
      photoPath: _asString(rawJson['photoPath']),
      aiDescription: _asString(rawJson['aiDescription']),
      aiSuggestedFoodPairings: _asBool(rawJson['aiSuggestedFoodPairings']),
      location:
          _asString(rawJson['location']) ?? _asString(rawJson['localisation']),
      cellarId: _asInt(rawJson['cellarId']),
      cellarPositionX: _asDouble(rawJson['cellarPositionX']),
      cellarPositionY: _asDouble(rawJson['cellarPositionY']),
      notes: _asString(rawJson['notes']),
      foodCategoryIds: _asIntList(rawJson['foodCategoryIds']),
    );
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) return null;
      return int.tryParse(normalized) ??
          int.tryParse(normalized.replaceAll(RegExp(r'[^0-9-]'), ''));
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized) ??
          double.tryParse(normalized.replaceAll(RegExp(r'[^0-9.-]'), ''));
    }
    return null;
  }

  bool _asBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'oui';
    }
    return false;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  List<String> _asStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => _asString(e)).whereType<String>().toList();
    }
    if (value is String) {
      return value
          .split(RegExp(r'[,;/]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<int> _asIntList(dynamic value) {
    if (value is! List) return const [];
    return value.map(_asInt).whereType<int>().toList();
  }

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
      cellarId: dbWine.cellarId,
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
      cellarId: Value(entity.cellarId),
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
    final normalized = value
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.-]'), '');
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
    if (value.contains('moelleux') ||
        value.contains('doux') ||
        value == 'sweet') {
      return WineColor.sweet;
    }
    return WineColor.red;
  }
}
