import 'package:drift/drift.dart' show Value;
import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/database/daos/bottle_placement_dao.dart';
import 'package:wine_cellar/database/daos/virtual_cellar_dao.dart';
import 'package:wine_cellar/database/app_database.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/virtual_cellar_repository.dart';

/// Concrete implementation of [VirtualCellarRepository] backed by Drift.
class VirtualCellarRepositoryImpl implements VirtualCellarRepository {
  final VirtualCellarDao _dao;
  final BottlePlacementDao _placementDao;

  VirtualCellarRepositoryImpl(this._dao, this._placementDao);

  // ── Read ────────────────────────────────────────────────────────────────────

  @override
  Stream<List<VirtualCellarEntity>> watchAll() {
    return _dao.watchAll().map(
      (list) => list.map(_toEntity).toList(),
    );
  }

  @override
  Future<Either<Failure, List<VirtualCellarEntity>>> getAll() async {
    try {
      final list = await _dao.getAll();
      return Right(list.map(_toEntity).toList());
    } catch (e) {
      return Left(CacheFailure('Impossible de charger les celliers.', cause: e));
    }
  }

  @override
  Future<Either<Failure, VirtualCellarEntity?>> getById(int id) async {
    try {
      final row = await _dao.getById(id);
      return Right(row != null ? _toEntity(row) : null);
    } catch (e) {
      return Left(CacheFailure('Impossible de charger le cellier.', cause: e));
    }
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, int>> create(VirtualCellarEntity cellar) async {
    try {
      final id = await _dao.insertCellar(
        VirtualCellarsCompanion.insert(
          name: cellar.name,
          rows: Value(cellar.rows),
          columns: Value(cellar.columns),
        ),
      );
      return Right(id);
    } catch (e) {
      return Left(CacheFailure('Impossible de créer le cellier.', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> update(VirtualCellarEntity cellar) async {
    if (cellar.id == null) {
      return Left(const CacheFailure('ID du cellier manquant pour la mise à jour.'));
    }
    try {
      await _dao.updateCellar(
        VirtualCellarsCompanion(
          id: Value(cellar.id!),
          name: Value(cellar.name),
          rows: Value(cellar.rows),
          columns: Value(cellar.columns),
        ),
      );
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Impossible de mettre à jour le cellier.', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(int id) async {
    try {
      await _placementDao.clearPlacementsForCellar(id);
      await _dao.deleteCellar(id);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Impossible de supprimer le cellier.', cause: e));
    }
  }

  // ── Wine placement ───────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<WineEntity>>> getWinesByCellarId(
      int cellarId) async {
    try {
      final placements = await _placementDao
          .watchPlacementsByCellarId(cellarId)
          .first;
      final byWine = <int, WineEntity>{};
      for (final item in placements) {
        byWine[item.wine.id] = _wineToEntity(item.wine);
      }
      return Right(byWine.values.toList());
    } catch (e) {
      return Left(CacheFailure('Impossible de charger les vins du cellier.', cause: e));
    }
  }

  @override
  Stream<List<WineEntity>> watchWinesByCellarId(int cellarId) {
    return _placementDao.watchPlacementsByCellarId(cellarId).map((list) {
      final byWine = <int, WineEntity>{};
      for (final item in list) {
        byWine[item.wine.id] = _wineToEntity(item.wine);
      }
      return byWine.values.toList();
    });
  }

  @override
  Stream<List<BottlePlacementEntity>> watchPlacementsByCellarId(int cellarId) {
    return _placementDao
        .watchPlacementsByCellarId(cellarId)
        .map((list) => list.map(_placementToEntity).toList());
  }

  @override
  Future<Either<Failure, List<BottlePlacementEntity>>> getPlacementsByWineId(
    int wineId,
  ) async {
    try {
      final rows = await _placementDao.getPlacementsByWineId(wineId);
      return Right(rows.map(_placementToEntity).toList());
    } catch (e) {
      return Left(CacheFailure('Impossible de charger les placements.', cause: e));
    }
  }

  @override
  Future<Either<Failure, int>> getPlacedBottleCount(int wineId) async {
    try {
      final count = await _placementDao.getPlacedBottleCountForWine(wineId);
      return Right(count);
    } catch (e) {
      return Left(CacheFailure('Impossible de compter les placements.', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> placeWine(
    int wineId, {
    required int cellarId,
    required int positionX,
    required int positionY,
  }) async {
    try {
      await _placementDao.placeBottle(
        wineId: wineId,
        cellarId: cellarId,
        positionX: positionX,
        positionY: positionY,
      );
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Impossible de placer la bouteille.', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> removePlacement(int placementId) async {
    try {
      await _placementDao.removePlacement(placementId);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Impossible de retirer la bouteille.', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> trimPlacementsForWine({
    required int wineId,
    required int maxPlacements,
  }) async {
    try {
      await _placementDao.trimPlacementsForWine(
        wineId: wineId,
        keepCount: maxPlacements,
      );
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Impossible d\'ajuster les placements.', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> moveBottleInCellar({
    required int placementId,
    required int newPositionX,
    required int newPositionY,
  }) async {
    try {
      await _placementDao.moveBottlePlacement(
        placementId: placementId,
        newPositionX: newPositionX,
        newPositionY: newPositionY,
      );
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Impossible de déplacer la bouteille.', cause: e));
    }
  }

  // ── Mapping ──────────────────────────────────────────────────────────────────

  VirtualCellarEntity _toEntity(VirtualCellar row) {
    return VirtualCellarEntity(
      id: row.id,
      name: row.name,
      rows: row.rows,
      columns: row.columns,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  WineEntity _wineToEntity(Wine row) {
    return WineEntity(
      id: row.id,
      name: row.name,
      appellation: row.appellation,
      producer: row.producer,
      region: row.region,
      country: row.country,
      color: WineColor.values.firstWhere(
        (c) => c.name == row.color,
        orElse: () => WineColor.red,
      ),
      vintage: row.vintage,
      grapeVarieties: WineEntity.parseGrapeVarieties(row.grapeVarieties),
      quantity: row.quantity,
      purchasePrice: row.purchasePrice,
      purchaseDate: row.purchaseDate,
      drinkFromYear: row.drinkFromYear,
      aiSuggestedDrinkFromYear: row.aiSuggestedDrinkFromYear,
      drinkUntilYear: row.drinkUntilYear,
      aiSuggestedDrinkUntilYear: row.aiSuggestedDrinkUntilYear,
      tastingNotes: row.tastingNotes,
      rating: row.rating,
      photoPath: row.photoPath,
      aiDescription: row.aiDescription,
      aiSuggestedFoodPairings: row.aiSuggestedFoodPairings,
      location: row.location,
      cellarId: row.cellarId,
      cellarPositionX: row.cellarPositionX,
      cellarPositionY: row.cellarPositionY,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  BottlePlacementEntity _placementToEntity(BottlePlacementWithWine row) {
    return BottlePlacementEntity(
      id: row.placement.id,
      wineId: row.placement.wineId,
      cellarId: row.placement.cellarId,
      positionX: row.placement.positionX,
      positionY: row.placement.positionY,
      createdAt: row.placement.createdAt,
      wine: _wineToEntity(row.wine),
    );
  }
}
