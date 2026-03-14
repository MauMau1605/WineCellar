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