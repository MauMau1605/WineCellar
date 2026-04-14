import 'package:flutter_test/flutter_test.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';

void main() {
  group('CsvColumnMapping', () {
    test('hasMinimumFields est true quand name est défini', () {
      const mapping = CsvColumnMapping(name: 1);
      expect(mapping.hasMinimumFields, isTrue);
    });

    test('hasMinimumFields est false quand name est null', () {
      const mapping = CsvColumnMapping(vintage: 2);
      expect(mapping.hasMinimumFields, isFalse);
    });

    test('columnForField retourne le bon numéro de colonne', () {
      const mapping = CsvColumnMapping(name: 1, vintage: 3, region: 5);
      expect(mapping.columnForField('name'), 1);
      expect(mapping.columnForField('vintage'), 3);
      expect(mapping.columnForField('region'), 5);
      expect(mapping.columnForField('producer'), isNull);
    });

    test('fromFieldMap construit correctement un mapping depuis une Map', () {
      final fieldMap = <String, int?>{
        'name': 1,
        'vintage': 2,
        'producer': 3,
        'appellation': null,
        'color': 5,
      };
      final mapping = CsvColumnMapping.fromFieldMap(fieldMap);

      expect(mapping.name, 1);
      expect(mapping.vintage, 2);
      expect(mapping.producer, 3);
      expect(mapping.appellation, isNull);
      expect(mapping.color, 5);
    });

    test('toFieldMap retourne une Map avec tous les champs', () {
      const mapping = CsvColumnMapping(
        name: 1,
        vintage: 2,
        producer: 3,
      );
      final fieldMap = mapping.toFieldMap();

      expect(fieldMap['name'], 1);
      expect(fieldMap['vintage'], 2);
      expect(fieldMap['producer'], 3);
      expect(fieldMap['appellation'], isNull);
      expect(fieldMap.length, CsvColumnMapping.fieldNames.length);
    });

    test('fromFieldMap → toFieldMap round-trip', () {
      final original = <String, int?>{
        'name': 1,
        'vintage': 3,
        'quantity': 5,
        'color': 7,
      };
      final mapping = CsvColumnMapping.fromFieldMap(original);
      final roundTripped = mapping.toFieldMap();

      for (final fieldName in CsvColumnMapping.fieldNames) {
        expect(roundTripped[fieldName], original[fieldName]);
      }
    });

    test('fieldNames contient tous les champs attendus', () {
      expect(CsvColumnMapping.fieldNames, contains('name'));
      expect(CsvColumnMapping.fieldNames, contains('vintage'));
      expect(CsvColumnMapping.fieldNames, contains('producer'));
      expect(CsvColumnMapping.fieldNames, contains('appellation'));
      expect(CsvColumnMapping.fieldNames, contains('quantity'));
      expect(CsvColumnMapping.fieldNames, contains('color'));
      expect(CsvColumnMapping.fieldNames, contains('region'));
      expect(CsvColumnMapping.fieldNames, contains('country'));
      expect(CsvColumnMapping.fieldNames, contains('grapeVarieties'));
      expect(CsvColumnMapping.fieldNames, contains('purchasePrice'));
      expect(CsvColumnMapping.fieldNames, contains('location'));
      expect(CsvColumnMapping.fieldNames, contains('notes'));
    });

    test('fieldLabels a une entrée pour chaque fieldName', () {
      for (final fieldName in CsvColumnMapping.fieldNames) {
        expect(
          CsvColumnMapping.fieldLabels.containsKey(fieldName),
          isTrue,
          reason: 'fieldLabels manque le label pour "$fieldName"',
        );
      }
    });
  });
}
