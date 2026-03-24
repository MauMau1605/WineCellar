import 'package:drift/drift.dart';

/// Virtual cellar table — represents a physical wine rack or storage space.
/// A cellar has a grid of [rows] × [columns] slots where bottles can be placed.
class VirtualCellars extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get rows => integer().withDefault(const Constant(5))();
  IntColumn get columns => integer().withDefault(const Constant(5))();
  TextColumn get emptyCells => text().nullable()();
  TextColumn get theme => text().withDefault(const Constant('classic'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
