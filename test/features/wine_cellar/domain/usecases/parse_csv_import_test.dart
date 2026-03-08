import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_import_row.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/parse_csv_import.dart';

class _MockWineRepository extends Mock implements WineRepository {}

void main() {
  late _MockWineRepository repository;
  late ParseCsvImportUseCase useCase;

  setUpAll(() {
    registerFallbackValue(const CsvColumnMapping(name: 1));
  });

  setUp(() {
    repository = _MockWineRepository();
    useCase = ParseCsvImportUseCase(repository);
  });

  test('retourne ValidationFailure quand le CSV est vide', () async {
    final params = ParseCsvImportParams(
      csvContent: '   ',
      mapping: const CsvColumnMapping(name: 1),
    );

    final result = await useCase(params);

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('Doit retourner un Failure'),
    );
  });

  test('retourne ValidationFailure si la colonne nom est absente', () async {
    final params = ParseCsvImportParams(
      csvContent: 'a,b,c',
      mapping: const CsvColumnMapping(),
    );

    final result = await useCase(params);

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('Doit retourner un Failure'),
    );
  });

  test('retourne ValidationFailure si aucune ligne exploitable', () async {
    when(
      () => repository.parseCsvRows(any(), any(), hasHeader: any(named: 'hasHeader')),
    ).thenAnswer((_) async => const []);

    final params = ParseCsvImportParams(
      csvContent: 'Nom,Millésime\n',
      mapping: const CsvColumnMapping(name: 1),
    );

    final result = await useCase(params);

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('Doit retourner un Failure'),
    );
  });

  test('retourne les lignes extraites en cas de succès', () async {
    const rows = [
      CsvImportRow(sourceRowNumber: 2, name: 'Château Test', quantity: 2),
    ];

    when(
      () => repository.parseCsvRows(any(), any(), hasHeader: any(named: 'hasHeader')),
    ).thenAnswer((_) async => rows);

    final params = ParseCsvImportParams(
      csvContent: 'Nom,Quantité\nChâteau Test,2',
      mapping: const CsvColumnMapping(name: 1, quantity: 2),
    );

    final result = await useCase(params);

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Doit retourner un succès'),
      (values) {
        expect(values.length, 1);
        expect(values.first.name, 'Château Test');
      },
    );
  });
}
