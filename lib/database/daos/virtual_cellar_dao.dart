import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/virtual_cellars.dart';
import '../tables/wines.dart';

part 'virtual_cellar_dao.g.dart';

@DriftAccessor(tables: [VirtualCellars, Wines])
class VirtualCellarDao extends DatabaseAccessor<AppDatabase>
    with _$VirtualCellarDaoMixin {
  VirtualCellarDao(super.db);

  /// Watch all virtual cellars ordered by name.
  Stream<List<VirtualCellar>> watchAll() {
    return (select(virtualCellars)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  /// Get all virtual cellars.
  Future<List<VirtualCellar>> getAll() {
    return (select(virtualCellars)
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  /// Get a single virtual cellar by ID.
  Future<VirtualCellar?> getById(int id) {
    return (select(virtualCellars)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new virtual cellar and return its ID.
  Future<int> insertCellar(VirtualCellarsCompanion entry) {
    return into(virtualCellars).insert(entry);
  }

  /// Update an existing virtual cellar.
  Future<bool> updateCellar(VirtualCellarsCompanion entry) {
    return update(virtualCellars).replace(
      entry.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Delete a virtual cellar by ID.
  /// Wines placed in this cellar will NOT be deleted; their cellarId will be
  /// cleared by [clearCellarPlacementsForCellar] before deletion.
  Future<int> deleteCellar(int id) {
    return (delete(virtualCellars)..where((c) => c.id.equals(id))).go();
  }

  /// Watch wines placed in a given cellar.
  Stream<List<Wine>> watchWinesByCellarId(int cellarId) {
    return (select(wines)
          ..where((w) => w.cellarId.equals(cellarId))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .watch();
  }

  /// Get wines placed in a given cellar.
  Future<List<Wine>> getWinesByCellarId(int cellarId) {
    return (select(wines)
          ..where((w) => w.cellarId.equals(cellarId))
          ..orderBy([(w) => OrderingTerm.asc(w.name)]))
        .get();
  }

  /// Remove all wines from a cellar (set their placement to null).
  Future<void> clearCellarPlacementsForCellar(int cellarId) async {
    await (update(wines)..where((w) => w.cellarId.equals(cellarId))).write(
      WinesCompanion(
        cellarId: const Value(null),
        cellarPositionX: const Value(null),
        cellarPositionY: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Place (or remove) a wine in/from a cellar slot.
  Future<void> updateCellarPlacement(
    int wineId,
    int? cellarId,
    double? posX,
    double? posY,
  ) async {
    await (update(wines)..where((w) => w.id.equals(wineId))).write(
      WinesCompanion(
        cellarId: Value(cellarId),
        cellarPositionX: Value(posX),
        cellarPositionY: Value(posY),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
