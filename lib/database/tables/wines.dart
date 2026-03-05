import 'package:drift/drift.dart';

/// Wines table - main entity
/// All nullable columns can be easily added in future migrations
class Wines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get appellation => text().nullable()();
  TextColumn get producer => text().nullable()();
  TextColumn get region => text().nullable()();
  TextColumn get country => text().withDefault(const Constant('France'))();
  TextColumn get color => text()(); // WineColor enum name
  IntColumn get vintage => integer().nullable()();
  TextColumn get grapeVarieties => text().nullable()(); // JSON array as string
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get purchasePrice => real().nullable()();
  DateTimeColumn get purchaseDate => dateTime().nullable()();
  IntColumn get drinkFromYear => integer().nullable()();
  IntColumn get drinkUntilYear => integer().nullable()();
  TextColumn get tastingNotes => text().nullable()();
  IntColumn get rating => integer().nullable()(); // 0-5
  TextColumn get photoPath => text().nullable()();
  TextColumn get aiDescription => text().nullable()();
  TextColumn get location => text().nullable()(); // e.g. 'Cave maison', 'Garage'
  TextColumn get notes => text().nullable()(); // free-form user notes
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
