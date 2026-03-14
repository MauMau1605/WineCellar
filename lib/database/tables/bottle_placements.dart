import 'package:drift/drift.dart';

/// Physical placement of a single bottle in a virtual cellar slot.
class BottlePlacements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wineId => integer()();
  IntColumn get cellarId => integer()();

  /// 0-based column index.
  IntColumn get positionX => integer()();

  /// 0-based row index.
  IntColumn get positionY => integer()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {cellarId, positionX, positionY},
      ];
}
