import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/bottle_placements.dart';
import '../tables/wines.dart';

part 'bottle_placement_dao.g.dart';

class BottlePlacementWithWine {
  final BottlePlacement placement;
  final Wine wine;

  BottlePlacementWithWine({required this.placement, required this.wine});
}

@DriftAccessor(tables: [BottlePlacements, Wines])
class BottlePlacementDao extends DatabaseAccessor<AppDatabase>
    with _$BottlePlacementDaoMixin {
  BottlePlacementDao(super.db);

  Stream<List<BottlePlacementWithWine>> watchPlacementsByCellarId(int cellarId) {
    final query = select(bottlePlacements).join([
      innerJoin(wines, wines.id.equalsExp(bottlePlacements.wineId)),
    ])
      ..where(bottlePlacements.cellarId.equals(cellarId))
      ..orderBy([
        OrderingTerm.asc(bottlePlacements.positionY),
        OrderingTerm.asc(bottlePlacements.positionX),
      ]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => BottlePlacementWithWine(
                  placement: row.readTable(bottlePlacements),
                  wine: row.readTable(wines),
                ),
              )
              .toList(),
        );
  }

  Future<List<BottlePlacementWithWine>> getPlacementsByWineId(int wineId) async {
    final query = select(bottlePlacements).join([
      innerJoin(wines, wines.id.equalsExp(bottlePlacements.wineId)),
    ])
      ..where(bottlePlacements.wineId.equals(wineId))
      ..orderBy([
        OrderingTerm.asc(bottlePlacements.cellarId),
        OrderingTerm.asc(bottlePlacements.positionY),
        OrderingTerm.asc(bottlePlacements.positionX),
      ]);

    final rows = await query.get();
    return rows
        .map(
          (row) => BottlePlacementWithWine(
            placement: row.readTable(bottlePlacements),
            wine: row.readTable(wines),
          ),
        )
        .toList();
  }

  Future<int> getPlacedBottleCountForWine(int wineId) async {
    final countExpr = bottlePlacements.id.count();
    final query = selectOnly(bottlePlacements)
      ..addColumns([countExpr])
      ..where(bottlePlacements.wineId.equals(wineId));

    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  Future<bool> isSlotOccupied({
    required int cellarId,
    required int positionX,
    required int positionY,
  }) async {
    final row = await (select(bottlePlacements)
          ..where((p) =>
              p.cellarId.equals(cellarId) &
              p.positionX.equals(positionX) &
              p.positionY.equals(positionY)))
        .getSingleOrNull();
    return row != null;
  }

  Future<int> placeBottle({
    required int wineId,
    required int cellarId,
    required int positionX,
    required int positionY,
  }) async {
    final occupied = await isSlotOccupied(
      cellarId: cellarId,
      positionX: positionX,
      positionY: positionY,
    );
    if (occupied) {
      throw StateError('Emplacement déjà occupé.');
    }

    return into(bottlePlacements).insert(
      BottlePlacementsCompanion.insert(
        wineId: wineId,
        cellarId: cellarId,
        positionX: positionX,
        positionY: positionY,
      ),
    );
  }

  Future<int> removePlacement(int placementId) {
    return (delete(bottlePlacements)..where((p) => p.id.equals(placementId))).go();
  }

  Future<int> clearPlacementsForWine(int wineId) {
    return (delete(bottlePlacements)..where((p) => p.wineId.equals(wineId))).go();
  }

  Future<int> clearPlacementsForCellar(int cellarId) {
    return (delete(bottlePlacements)..where((p) => p.cellarId.equals(cellarId))).go();
  }

  Future<int> clearAllPlacements() {
    return delete(bottlePlacements).go();
  }

  Future<void> trimPlacementsForWine({
    required int wineId,
    required int keepCount,
  }) async {
    if (keepCount < 0) keepCount = 0;

    final placements = await (select(bottlePlacements)
          ..where((p) => p.wineId.equals(wineId))
          ..orderBy([
            (p) => OrderingTerm.desc(p.createdAt),
            (p) => OrderingTerm.desc(p.id),
          ]))
        .get();

    if (placements.length <= keepCount) return;

    final toRemove = placements.skip(keepCount);
    for (final placement in toRemove) {
      await (delete(bottlePlacements)..where((p) => p.id.equals(placement.id))).go();
    }
  }
}
