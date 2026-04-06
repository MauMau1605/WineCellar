import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/data/repositories/wine_repository_impl.dart';
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
  });
}