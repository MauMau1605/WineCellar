import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import '../entities/bottle_placement_entity.dart';
import '../entities/virtual_cellar_entity.dart';
import '../entities/wine_entity.dart';

/// Abstract repository for virtual cellar operations.
abstract class VirtualCellarRepository {
  /// Watch all virtual cellars (reactive stream).
  Stream<List<VirtualCellarEntity>> watchAll();

  /// Get all virtual cellars as a one-shot list.
  Future<Either<Failure, List<VirtualCellarEntity>>> getAll();

  /// Get a single virtual cellar by ID.
  Future<Either<Failure, VirtualCellarEntity?>> getById(int id);

  /// Create a new virtual cellar and return its new ID.
  Future<Either<Failure, int>> create(VirtualCellarEntity cellar);

  /// Update an existing virtual cellar (name / dimensions).
  Future<Either<Failure, Unit>> update(VirtualCellarEntity cellar);

  /// Delete a virtual cellar. Wines placed in it are automatically unplaced.
  Future<Either<Failure, Unit>> delete(int id);

  /// Get all wines placed in a given cellar (unique wine references).
  Future<Either<Failure, List<WineEntity>>> getWinesByCellarId(int cellarId);

  /// Watch all wines placed in a given cellar (unique wine references).
  Stream<List<WineEntity>> watchWinesByCellarId(int cellarId);

  /// Watch all physical bottle placements for a cellar.
  Stream<List<BottlePlacementEntity>> watchPlacementsByCellarId(int cellarId);

  /// Get all physical bottle placements for a wine reference.
  Future<Either<Failure, List<BottlePlacementEntity>>> getPlacementsByWineId(
    int wineId,
  );

  /// Number of placed bottles for a wine reference.
  Future<Either<Failure, int>> getPlacedBottleCount(int wineId);

  /// Place one bottle in a cellar slot.
  Future<Either<Failure, Unit>> placeWine(
    int wineId, {
    required int cellarId,
    required int positionX,
    required int positionY,
  });

  /// Remove a single physical placement by ID.
  Future<Either<Failure, Unit>> removePlacement(int placementId);

  /// Keep at most [maxPlacements] physical placements for the wine.
  Future<Either<Failure, Unit>> trimPlacementsForWine({
    required int wineId,
    required int maxPlacements,
  });

  /// Move a bottle placement to a new position in the cellar.
  /// Returns failure if the target slot is occupied.
  Future<Either<Failure, Unit>> moveBottleInCellar({
    required int placementId,
    required int newPositionX,
    required int newPositionY,
  });
}
