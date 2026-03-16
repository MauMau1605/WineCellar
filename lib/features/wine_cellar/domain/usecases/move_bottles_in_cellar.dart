import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import '../repositories/virtual_cellar_repository.dart';

/// Use case for moving multiple bottles in a cellar.
///
/// Takes a mapping of placement IDs to their new positions and moves them.
/// If any target position is occupied, no movements are performed.
class MoveBottlesInCellar {
  final VirtualCellarRepository _repository;

  MoveBottlesInCellar(this._repository);

  /// Move selected bottles as a translated group.
  ///
  /// The translation is computed from [anchorPlacementId] source position to
  /// ([targetAnchorX], [targetAnchorY]).
  Future<Either<Failure, Unit>> call({
    required List<BottlePlacementEntity> allPlacements,
    required Set<int> selectedPlacementIds,
    required int anchorPlacementId,
    required int targetAnchorX,
    required int targetAnchorY,
    required int maxColumns,
    required int maxRows,
  }) async {
    if (selectedPlacementIds.isEmpty) {
      return const Right(unit);
    }

    try {
      final placementsById = <int, BottlePlacementEntity>{
        for (final p in allPlacements) p.id: p,
      };

      final anchor = placementsById[anchorPlacementId];
      if (anchor == null) {
        return const Left(CacheFailure('Bouteille d ancrage introuvable.'));
      }

      final selectedPlacements = selectedPlacementIds
          .map((id) => placementsById[id])
          .whereType<BottlePlacementEntity>()
          .toList(growable: false);

      if (selectedPlacements.isEmpty) {
        return const Left(CacheFailure('Aucune bouteille sélectionnée.'));
      }

      final deltaX = targetAnchorX - anchor.positionX;
      final deltaY = targetAnchorY - anchor.positionY;

      if (deltaX == 0 && deltaY == 0) {
        return const Right(unit);
      }

      final occupiedByOthers = <(int, int)>{
        for (final p in allPlacements)
          if (!selectedPlacementIds.contains(p.id)) (p.positionX, p.positionY),
      };

      final targetPositions = <(int, int)>{};
      final movements = <int, (int, int)>{};

      for (final placement in selectedPlacements) {
        final newX = placement.positionX + deltaX;
        final newY = placement.positionY + deltaY;

        if (newX < 0 || newX >= maxColumns || newY < 0 || newY >= maxRows) {
          return const Left(CacheFailure('Déplacement hors des limites du cellier.'));
        }

        if (occupiedByOthers.contains((newX, newY))) {
          return const Left(CacheFailure('Impossible: emplacement cible occupé.'));
        }

        if (!targetPositions.add((newX, newY))) {
          return const Left(CacheFailure('Impossible: chevauchement interne de la sélection.'));
        }

        movements[placement.id] = (newX, newY);
      }

      // Move in front-to-back order along translation vector to avoid
      // transient conflicts when a target slot equals another selected source.
      final ordered = selectedPlacements.toList(growable: false)
        ..sort((a, b) {
          final projA = a.positionX * deltaX + a.positionY * deltaY;
          final projB = b.positionX * deltaX + b.positionY * deltaY;
          return projB.compareTo(projA);
        });

      for (final placement in ordered) {
        final target = movements[placement.id];
        if (target == null) continue;
        final (newX, newY) = target;

        final result = await _repository.moveBottleInCellar(
          placementId: placement.id,
          newPositionX: newX,
          newPositionY: newY,
        );

        if (result.isLeft()) {
          return result;
        }
      }

      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure('Erreur lors du déplacement des bouteilles.', cause: e));
    }
  }
}
