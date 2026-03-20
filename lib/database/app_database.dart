import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/food_pairing_catalog.dart';
import 'tables/wines.dart';
import 'tables/food_categories.dart';
import 'tables/wine_food_pairings.dart';
import 'tables/virtual_cellars.dart';
import 'tables/bottle_placements.dart';
import 'daos/wine_dao.dart';
import 'daos/food_category_dao.dart';
import 'daos/virtual_cellar_dao.dart';
import 'daos/bottle_placement_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Wines,
    FoodCategories,
    WineFoodPairings,
    VirtualCellars,
    BottlePlacements,
  ],
  daos: [WineDao, FoodCategoryDao, VirtualCellarDao, BottlePlacementDao],
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
        await _migrateWithoutDataLoss(m);
        await _seedFoodCategories();
      },
    );
  }

  Future<void> _migrateWithoutDataLoss(Migrator m) async {
    await _createTableIfMissing('wines', () => m.createTable(wines));
    await _createTableIfMissing(
      'food_categories',
      () => m.createTable(foodCategories),
    );
    await _createTableIfMissing(
      'wine_food_pairings',
      () => m.createTable(wineFoodPairings),
    );

    await _addColumnIfMissing(
      tableName: 'wines',
      columnName: 'ai_suggested_drink_from_year',
      addColumn: () => m.addColumn(wines, wines.aiSuggestedDrinkFromYear),
    );
    await _addColumnIfMissing(
      tableName: 'wines',
      columnName: 'ai_suggested_drink_until_year',
      addColumn: () => m.addColumn(wines, wines.aiSuggestedDrinkUntilYear),
    );
    await _addColumnIfMissing(
      tableName: 'wines',
      columnName: 'ai_suggested_food_pairings',
      addColumn: () => m.addColumn(wines, wines.aiSuggestedFoodPairings),
    );
    await _addColumnIfMissing(
      tableName: 'wines',
      columnName: 'cellar_position_x',
      addColumn: () => m.addColumn(wines, wines.cellarPositionX),
    );
    await _addColumnIfMissing(
      tableName: 'wines',
      columnName: 'cellar_position_y',
      addColumn: () => m.addColumn(wines, wines.cellarPositionY),
    );
    await _addColumnIfMissing(
      tableName: 'wines',
      columnName: 'notes',
      addColumn: () => m.addColumn(wines, wines.notes),
    );

    // v4 — virtual cellars
    await _createTableIfMissing(
      'virtual_cellars',
      () => m.createTable(virtualCellars),
    );
    await _addColumnIfMissing(
      tableName: 'virtual_cellars',
      columnName: 'empty_cells',
      addColumn: () => m.addColumn(virtualCellars, virtualCellars.emptyCells),
    );
    await _addColumnIfMissing(
      tableName: 'wines',
      columnName: 'cellar_id',
      addColumn: () => m.addColumn(wines, wines.cellarId),
    );

    // v5 — one placement row per physical bottle.
    await _createTableIfMissing(
      'bottle_placements',
      () => m.createTable(bottlePlacements),
    );

    // Migrate legacy per-wine position into one per-bottle placement row.
    await customStatement('''
      INSERT INTO bottle_placements (wine_id, cellar_id, position_x, position_y)
      SELECT w.id, w.cellar_id, CAST(w.cellar_position_x AS INTEGER), CAST(w.cellar_position_y AS INTEGER)
      FROM wines w
      WHERE w.cellar_id IS NOT NULL
        AND w.cellar_position_x IS NOT NULL
        AND w.cellar_position_y IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM bottle_placements bp
          WHERE bp.cellar_id = w.cellar_id
            AND bp.position_x = CAST(w.cellar_position_x AS INTEGER)
            AND bp.position_y = CAST(w.cellar_position_y AS INTEGER)
        );
    ''');
  }

  Future<void> _createTableIfMissing(
    String tableName,
    Future<void> Function() createTable,
  ) async {
    final exists = await _tableExists(tableName);
    if (!exists) {
      await createTable();
    }
  }

  Future<void> _addColumnIfMissing({
    required String tableName,
    required String columnName,
    required Future<void> Function() addColumn,
  }) async {
    final exists = await _columnExists(tableName, columnName);
    if (!exists) {
      await addColumn();
    }
  }

  Future<bool> _tableExists(String tableName) async {
    final result = await customSelect(
      'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
      variables: [const Variable<String>('table'), Variable<String>(tableName)],
    ).getSingleOrNull();

    return result != null;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final result = await customSelect("PRAGMA table_info('$tableName')").get();

    return result.any((row) => row.read<String>('name') == columnName);
  }

  /// Pre-populate food categories with common French food types
  Future<void> _seedFoodCategories() async {
    final existingCategories = await select(foodCategories).get();
    final existingNames = existingCategories.map((row) => row.name).toSet();

    for (final category in _defaultFoodCategories) {
      if (existingNames.contains(category.name)) {
        continue;
      }

      await into(foodCategories).insert(
        FoodCategoriesCompanion.insert(
          name: category.name,
          icon: Value(category.icon),
          sortOrder: Value(category.sortOrder),
        ),
      );
    }
  }

  List<FoodPairingPreset> get _defaultFoodCategories =>
      defaultFoodPairingCatalog;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await _resolveDatabaseFile();
    return NativeDatabase.createInBackground(file);
  });
}

Future<File> _resolveDatabaseFile() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final documentsFile = File(
    p.join(documentsDir.path, AppConstants.databaseName),
  );

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final installDir = await _findWritableInstallDirectory();

    if (installDir != null) {
      final installFile = File(
        p.join(installDir.path, AppConstants.databaseName),
      );

      if (!await installFile.exists() && await documentsFile.exists()) {
        try {
          await documentsFile.copy(installFile.path);
        } catch (_) {
          return documentsFile;
        }
      }

      return installFile;
    }
  }

  return documentsFile;
}

Future<Directory?> _findWritableInstallDirectory() async {
  final executableDir = Directory(p.dirname(Platform.resolvedExecutable));

  if (!await executableDir.exists()) {
    return null;
  }

  final probePath = p.join(executableDir.path, '.wine_cellar_write_probe');
  final probeFile = File(probePath);

  try {
    await probeFile.writeAsString('ok', flush: true);
    if (await probeFile.exists()) {
      await probeFile.delete();
    }
    return executableDir;
  } catch (_) {
    return null;
  }
}
