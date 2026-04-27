import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/wine_repository_impl.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

void main() {
  group('WineRepositoryImpl JSON snapshot', () {
    test('exporte et restaure une cave complète avec celliers et placements',
        () async {
      final sourceDb = AppDatabase.forTesting(NativeDatabase.memory());
      final sourceRepository = WineRepositoryImpl(
        sourceDb.wineDao,
        sourceDb.foodCategoryDao,
        sourceDb.virtualCellarDao,
        sourceDb.bottlePlacementDao,
      );

      final sourceCellarId = await sourceDb.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(
          name: 'Cellier principal',
          rows: const Value(3),
          columns: const Value(4),
        ),
      );

      final sourceBordeauxId = await sourceRepository.addWine(
        const WineEntity(
          name: 'Bordeaux Superieur',
          color: WineColor.red,
          quantity: 2,
        ),
      );
      await sourceDb.bottlePlacementDao.placeBottle(
        wineId: sourceBordeauxId,
        cellarId: sourceCellarId,
        positionX: 1,
        positionY: 2,
      );

      await sourceRepository.addWine(
        const WineEntity(
          name: 'Chablis Vieilles Vignes',
          color: WineColor.white,
          quantity: 1,
        ),
      );

      final exportedJson = await sourceRepository.exportToJson();
      final exportedMap = jsonDecode(exportedJson) as Map<String, dynamic>;
      expect(exportedMap['snapshotType'], 'full_cellar');
      expect(exportedMap['virtualCellars'], isA<List<dynamic>>());
      expect(exportedMap['bottlePlacements'], isA<List<dynamic>>());

      await sourceDb.close();

      final targetDb = AppDatabase.forTesting(NativeDatabase.memory());
      final targetRepository = WineRepositoryImpl(
        targetDb.wineDao,
        targetDb.foodCategoryDao,
        targetDb.virtualCellarDao,
        targetDb.bottlePlacementDao,
      );

      final oldCellarId = await targetDb.virtualCellarDao.insertCellar(
        VirtualCellarsCompanion.insert(
          name: 'Ancien cellier',
          rows: const Value(2),
          columns: const Value(2),
        ),
      );
      final temporaryWineId = await targetRepository.addWine(
        const WineEntity(
          name: 'Vin Temporaire',
          color: WineColor.rose,
        ),
      );
      await targetDb.bottlePlacementDao.placeBottle(
        wineId: temporaryWineId,
        cellarId: oldCellarId,
        positionX: 0,
        positionY: 0,
      );

      final importedCount = await targetRepository.importFromJson(exportedJson);
      expect(importedCount, 2);

      final restoredCellars = await targetDb.virtualCellarDao.getAll();
      expect(restoredCellars, hasLength(1));
      expect(restoredCellars.single.name, 'Cellier principal');

      final restoredWines = await targetRepository.getAllWines();
      expect(restoredWines, hasLength(2));
      expect(
        restoredWines.any((wine) => wine.name == 'Vin Temporaire'),
        isFalse,
      );

      final restoredBordeaux = restoredWines.firstWhere(
        (wine) => wine.name == 'Bordeaux Superieur',
      );
      expect(restoredBordeaux.cellarId, isNull);

      final restoredPlacements = await targetDb.bottlePlacementDao
          .getPlacementsByWineId(restoredBordeaux.id!);
      expect(restoredPlacements, hasLength(1));
      expect(restoredPlacements.single.placement.cellarId, restoredCellars.single.id);
      expect(restoredPlacements.single.placement.positionX, 1);
      expect(restoredPlacements.single.placement.positionY, 2);

      final restoredChablis = restoredWines.firstWhere(
        (wine) => wine.name == 'Chablis Vieilles Vignes',
      );
      expect(restoredChablis.cellarId, isNull);

      final temporaryPlacements =
          await targetDb.bottlePlacementDao.getPlacementsByWineId(temporaryWineId);
      expect(temporaryPlacements, isEmpty);

      await targetDb.close();
    });

    test(
        'backfille la localisation depuis le nom de la cave pour les vins sans localisation',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WineRepositoryImpl(
        db.wineDao,
        db.foodCategoryDao,
        db.virtualCellarDao,
        db.bottlePlacementDao,
      );

      // Snapshot avec deux vins :
      // - l'un sans localisation ET placé en cave → doit recevoir le nom de la cave
      // - l'autre avec localisation ET placé en cave → ne doit pas être modifié
      // - le troisième sans localisation ET non placé → doit rester sans localisation
      final snapshotJson = jsonEncode({
        'snapshotType': 'full_cellar',
        'virtualCellars': [
          {
            'id': 1,
            'name': 'Cave du salon',
            'rows': 3,
            'columns': 3,
            'emptyCells': null,
            'theme': null,
            'createdAt': '2025-01-01T00:00:00.000Z',
            'updatedAt': '2025-01-01T00:00:00.000Z',
          },
        ],
        'wines': [
          {
            'id': 10,
            'name': 'Bordeaux sans localisation',
            'color': 'red',
            'quantity': 1,
            'location': null,
          },
          {
            'id': 11,
            'name': 'Chablis avec localisation',
            'color': 'white',
            'quantity': 1,
            'location': 'Cave perso',
          },
          {
            'id': 12,
            'name': 'Rosé non placé sans localisation',
            'color': 'rose',
            'quantity': 1,
            'location': null,
          },
        ],
        'bottlePlacements': [
          {'id': 1, 'wineId': 10, 'cellarId': 1, 'positionX': 0, 'positionY': 0, 'createdAt': '2025-01-01T00:00:00.000Z'},
          {'id': 2, 'wineId': 11, 'cellarId': 1, 'positionX': 1, 'positionY': 0, 'createdAt': '2025-01-01T00:00:00.000Z'},
        ],
      });

      final importedCount = await repository.importFromJson(snapshotJson);
      expect(importedCount, 3);

      final wines = await repository.getAllWines();
      expect(wines, hasLength(3));

      final bordeaux =
          wines.firstWhere((w) => w.name == 'Bordeaux sans localisation');
      expect(
        bordeaux.location,
        'Cave du salon',
        reason:
            'Un vin sans localisation mais placé en cave doit recevoir le nom de la cave',
      );

      final chablis =
          wines.firstWhere((w) => w.name == 'Chablis avec localisation');
      expect(
        chablis.location,
        'Cave perso',
        reason: 'Un vin avec une localisation existante ne doit pas être modifié',
      );

      final rose =
          wines.firstWhere((w) => w.name == 'Rosé non placé sans localisation');
      expect(
        rose.location,
        isNull,
        reason:
            'Un vin sans localisation et sans placement ne doit pas être modifié',
      );

      await db.close();
    });

    test('importe un JSON legacy avec types hétérogènes en conservant les infos vin',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WineRepositoryImpl(
        db.wineDao,
        db.foodCategoryDao,
        db.virtualCellarDao,
        db.bottlePlacementDao,
      );

      final legacyJson = jsonEncode({
        'version': 1,
        'wines': [
          {
            'id': '42',
            'name': 'Cote du Rhone',
            'producer': 'Domaine Test',
            'country': 'France',
            'color': 'Rouge',
            'vintage': '2019',
            'grapeVarieties': 'Grenache, Syrah',
            'quantity': '3',
            'purchasePrice': '12,50',
            'drinkFromYear': '2022',
            'drinkUntilYear': '2028',
            'aiSuggestedFoodPairings': 'true',
            'location': 'Cave maison',
            'cellarId': '9',
            'cellarPositionX': '2',
            'cellarPositionY': 1,
            'notes': 'Import legacy',
            'foodCategoryIds': ['1', 2],
          },
        ],
      });

      final importedCount = await repository.importFromJson(legacyJson);
      expect(importedCount, 1);

      final wines = await repository.getAllWines();
      expect(wines, hasLength(1));

      final wine = wines.single;
      expect(wine.name, 'Cote du Rhone');
      expect(wine.producer, 'Domaine Test');
      expect(wine.color, WineColor.red);
      expect(wine.vintage, 2019);
      expect(wine.quantity, 3);
      expect(wine.purchasePrice, 12.5);
      expect(wine.drinkFromYear, 2022);
      expect(wine.drinkUntilYear, 2028);
      expect(wine.aiSuggestedFoodPairings, isTrue);
      expect(wine.location, 'Cave maison');
      expect(wine.notes, 'Import legacy');

      // Legacy cave placement fields are intentionally dropped during import.
      expect(wine.cellarId, isNull);
      expect(wine.cellarPositionX, isNull);
      expect(wine.cellarPositionY, isNull);

      await db.close();
    });

    test('importe un tableau JSON racine en ignorant les entrées invalides',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WineRepositoryImpl(
        db.wineDao,
        db.foodCategoryDao,
        db.virtualCellarDao,
        db.bottlePlacementDao,
      );

      final jsonArray = jsonEncode([
        {
          'id': 1,
          'name': 'Vin importé',
          'color': 'white',
          'quantity': 0,
          'cellarId': 4,
          'cellarPositionX': 2,
          'cellarPositionY': 1,
          'foodCategoryIds': [1, '2'],
        },
        {
          'id': 2,
          'color': 'red',
        },
      ]);

      final importedCount = await repository.importFromJson(jsonArray);
      expect(importedCount, 1);

      final wines = await repository.getAllWines();
      expect(wines, hasLength(1));
      expect(wines.single.name, 'Vin importé');
      expect(wines.single.color, WineColor.white);
      expect(wines.single.quantity, 1);
      expect(wines.single.cellarId, isNull);
      expect(wines.single.cellarPositionX, isNull);
      expect(wines.single.cellarPositionY, isNull);

      await db.close();
    });

    test('rejette un import JSON dont la racine n est ni une liste ni un objet',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WineRepositoryImpl(
        db.wineDao,
        db.foodCategoryDao,
        db.virtualCellarDao,
        db.bottlePlacementDao,
      );

      await expectLater(
        () => repository.importFromJson(jsonEncode('format-invalide')),
        throwsA(isA<FormatException>()),
      );

      await db.close();
    });
  });

  group('WineRepositoryImpl CSV import/export', () {
    test('parseCsvRows respecte headerLine, ignore les lignes vides et parse les champs utiles',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WineRepositoryImpl(
        db.wineDao,
        db.foodCategoryDao,
        db.virtualCellarDao,
        db.bottlePlacementDao,
      );

      const mapping = CsvColumnMapping(
        name: 1,
        vintage: 2,
        color: 3,
        grapeVarieties: 4,
        purchasePrice: 5,
        quantity: 6,
        location: 7,
        notes: 8,
      );

      const csv = 'Export cave 2026;;;;;;;\n'
          'Nom;Millésime;Couleur;Cépages;Prix;Quantité;Localisation;Notes\n'
          'Chablis;2020;Blanc;Chardonnay / Aligoté;12,50;2;Salon;Prêt\n'
          ';;;;;;;\n'
          'Champagne;2018;Pétillant;Pinot Noir, Chardonnay;;0;;\n';

      final rows = await repository.parseCsvRows(csv, mapping, headerLine: 2);

      expect(rows, hasLength(2));
      expect(rows.first.sourceRowNumber, 3);
      expect(rows.first.name, 'Chablis');
      expect(rows.first.vintage, 2020);
      expect(rows.first.grapeVarieties, ['Chardonnay', 'Aligoté']);
      expect(rows.first.purchasePrice, 12.5);
      expect(rows.first.quantity, 2);
      expect(rows.last.sourceRowNumber, 5);
      expect(rows.last.color, 'Pétillant');
      expect(rows.last.grapeVarieties, ['Pinot Noir', 'Chardonnay']);
      expect(rows.last.quantity, 0);

      await db.close();
    });

    test('importFromCsv applique override de localisation et normalise les valeurs',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WineRepositoryImpl(
        db.wineDao,
        db.foodCategoryDao,
        db.virtualCellarDao,
        db.bottlePlacementDao,
      );

      const mapping = CsvColumnMapping(
        name: 1,
        color: 2,
        quantity: 3,
        country: 4,
        location: 5,
        purchasePrice: 6,
      );

      const csv = 'Nom;Couleur;Quantité;Pays;Localisation;Prix achat\n'
          'Liquoreux Test;Moelleux;0;;Cave 1;18,90\n'
          'Rosé Test;Rosé;-2;Italie;Cave 2;\n'
          ';Rouge;1;France;;10,00\n';

      final importedCount = await repository.importFromCsv(
        csv,
        mapping,
        headerLine: 1,
        locationOverride: 'Réserve principale',
      );

      expect(importedCount, 2);

      final wines = await repository.getAllWines();
      expect(wines, hasLength(2));

      final sweetWine = wines.firstWhere((wine) => wine.name == 'Liquoreux Test');
      expect(sweetWine.color, WineColor.sweet);
      expect(sweetWine.quantity, 1);
      expect(sweetWine.country, 'France');
      expect(sweetWine.location, 'Réserve principale');
      expect(sweetWine.purchasePrice, 18.9);

      final roseWine = wines.firstWhere((wine) => wine.name == 'Rosé Test');
      expect(roseWine.color, WineColor.rose);
      expect(roseWine.quantity, 1);
      expect(roseWine.country, 'Italie');
      expect(roseWine.location, 'Réserve principale');

      await db.close();
    });

    test('exportToCsv sérialise les colonnes métier attendues', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WineRepositoryImpl(
        db.wineDao,
        db.foodCategoryDao,
        db.virtualCellarDao,
        db.bottlePlacementDao,
      );

      await repository.addWine(
        const WineEntity(
          name: 'Champagne Test',
          color: WineColor.sparkling,
          grapeVarieties: ['Pinot Noir', 'Chardonnay'],
          quantity: 3,
          purchasePrice: 24.5,
          drinkFromYear: 2026,
          drinkUntilYear: 2032,
          location: 'Cave nord',
          aiSuggestedFoodPairings: true,
          aiSuggestedDrinkFromYear: true,
          aiSuggestedDrinkUntilYear: false,
        ),
      );

      final exported = await repository.exportToCsv();
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(exported);

      expect(rows, hasLength(2));
      expect(rows.first[0], 'Nom');
      expect(rows.first[5], 'Couleur');
      expect(rows.first[17], 'IA: accords mets-vins');
      expect(rows[1][0], 'Champagne Test');
      expect(rows[1][5], 'Pétillant');
      expect(rows[1][7], 'Pinot Noir, Chardonnay');
      expect(rows[1][8], '3');
      expect(rows[1][9], '24.50');
      expect(rows[1][10], '2026');
      expect(rows[1][11], '2032');
      expect(rows[1][14], 'Cave nord');
      expect(rows[1][17], 'true');
      expect(rows[1][18], 'true');
      expect(rows[1][19], 'false');

      await db.close();
    });
  });

  group('WineRepositoryImpl.detectCsvSeparator', () {
    test('détecte la virgule comme séparateur', () {
      const csv = 'Nom,Millésime,Producteur\nMargaux,2015,Domaine X\n';
      expect(WineRepositoryImpl.detectCsvSeparator(csv), ',');
    });

    test('détecte le point-virgule comme séparateur', () {
      const csv = 'Nom;Millésime;Producteur\nMargaux;2015;Domaine X\n';
      expect(WineRepositoryImpl.detectCsvSeparator(csv), ';');
    });

    test('détecte la tabulation comme séparateur', () {
      const csv = 'Nom\tMillésime\tProducteur\nMargaux\t2015\tDomaine X\n';
      expect(WineRepositoryImpl.detectCsvSeparator(csv), '\t');
    });

    test('retourne virgule par défaut si contenu vide', () {
      expect(WineRepositoryImpl.detectCsvSeparator(''), ',');
    });

    test('préfère le séparateur le plus cohérent entre les lignes', () {
      // Semicolons are consistent (2 per line), commas are inconsistent
      const csv = 'Nom;Région;Pays\n'
          'Château Haut-Brion;Bordeaux;France\n'
          'Chablis, Premier Cru;Bourgogne;France\n';
      expect(WineRepositoryImpl.detectCsvSeparator(csv), ';');
    });
  });
}