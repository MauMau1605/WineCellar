import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:wine_cellar/database/app_database.dart';

void main() {
  group('AppDatabase migration', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wine_cellar_migration_test_');
      dbFile = File('${tempDir.path}/migration_test.db');
      _createLegacyV2Database(dbFile);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('upgrades without losing existing data', () async {
      final appDb = AppDatabase.forTesting(NativeDatabase(dbFile));

      final wines = await appDb.select(appDb.wines).get();
      expect(wines, hasLength(1));
      expect(wines.first.name, 'Vin Legacy');

      final pairingsCountRow = await appDb
          .customSelect('SELECT COUNT(*) AS c FROM wine_food_pairings')
          .getSingle();
      expect(pairingsCountRow.read<int>('c'), 1);

      final columns = await appDb.customSelect("PRAGMA table_info('wines')").get();
      final columnNames = columns.map((row) => row.read<String>('name')).toSet();

      expect(columnNames, contains('ai_suggested_drink_from_year'));
      expect(columnNames, contains('ai_suggested_drink_until_year'));
      expect(columnNames, contains('ai_suggested_food_pairings'));
      expect(columnNames, contains('cellar_position_x'));
      expect(columnNames, contains('cellar_position_y'));
      expect(columnNames, contains('notes'));

      final categories = await appDb.select(appDb.foodCategories).get();
      expect(categories.any((c) => c.name == 'Categorie legacy'), isTrue);
      expect(categories.any((c) => c.name == 'Viande rouge'), isTrue);

      await appDb.close();
    });
  });
}

void _createLegacyV2Database(File dbFile) {
  final db = sqlite3.open(dbFile.path);

  try {
    db.execute('PRAGMA foreign_keys = ON;');

    db.execute('''
      CREATE TABLE wines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        appellation TEXT,
        producer TEXT,
        region TEXT,
        country TEXT NOT NULL DEFAULT 'France',
        color TEXT NOT NULL,
        vintage INTEGER,
        grape_varieties TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        purchase_price REAL,
        purchase_date INTEGER,
        drink_from_year INTEGER,
        drink_until_year INTEGER,
        tasting_notes TEXT,
        rating INTEGER,
        photo_path TEXT,
        ai_description TEXT,
        location TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    db.execute('''
      CREATE TABLE food_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');

    db.execute('''
      CREATE TABLE wine_food_pairings (
        wine_id INTEGER NOT NULL,
        food_category_id INTEGER NOT NULL,
        PRIMARY KEY (wine_id, food_category_id),
        FOREIGN KEY (wine_id) REFERENCES wines(id) ON DELETE CASCADE,
        FOREIGN KEY (food_category_id) REFERENCES food_categories(id) ON DELETE CASCADE
      );
    ''');

    db.execute('''
      INSERT INTO wines (
        id,
        name,
        country,
        color,
        quantity,
        created_at,
        updated_at
      ) VALUES (1, 'Vin Legacy', 'France', 'red', 3, 1700000000, 1700000000);
    ''');

    db.execute('''
      INSERT INTO food_categories (id, name, icon, sort_order)
      VALUES (1, 'Categorie legacy', '🍽️', 999);
    ''');

    db.execute('''
      INSERT INTO wine_food_pairings (wine_id, food_category_id)
      VALUES (1, 1);
    ''');

    db.execute('PRAGMA user_version = 2;');
  } finally {
    db.dispose();
  }
}