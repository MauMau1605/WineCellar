import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_csv.dart';

class _MockWineRepository extends Mock implements WineRepository {}

void main() {
  late _MockWineRepository repository;
  late ImportWinesFromCsvUseCase useCase;

  setUpAll(() {
    registerFallbackValue(const CsvColumnMapping(name: 1));
  });

  setUp(() {
    repository = _MockWineRepository();
    useCase = ImportWinesFromCsvUseCase(repository);
  });

  test('retourne ValidationFailure quand le CSV est vide', () async {
    final params = ImportWinesFromCsvParams(
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

  test('retourne le nombre de vins importés en cas de succès', () async {
    when(
      () => repository.importFromCsv(
        any(),
        any(),
        headerLine: any(named: 'headerLine'),
        locationOverride: any(named: 'locationOverride'),
      ),
    ).thenAnswer((_) async => 3);

    final params = ImportWinesFromCsvParams(
      csvContent: 'Nom\nVin1\nVin2\nVin3',
      mapping: const CsvColumnMapping(name: 1),
    );

    final result = await useCase(params);

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Doit retourner un succès'),
      (count) => expect(count, 3),
    );
  });

  test('passe locationOverride au repository', () async {
    when(
      () => repository.importFromCsv(
        any(),
        any(),
        headerLine: any(named: 'headerLine'),
        locationOverride: any(named: 'locationOverride'),
      ),
    ).thenAnswer((_) async => 2);

    final params = ImportWinesFromCsvParams(
      csvContent: 'Nom\nVin1\nVin2',
      mapping: const CsvColumnMapping(name: 1),
      locationOverride: 'Cave principale',
    );

    final result = await useCase(params);

    expect(result.isRight(), isTrue);

    final captured = verify(
      () => repository.importFromCsv(
        any(),
        any(),
        headerLine: any(named: 'headerLine'),
        locationOverride: captureAny(named: 'locationOverride'),
      ),
    ).captured;

    expect(captured.single, 'Cave principale');
  });

  test('passe null locationOverride quand non spécifié', () async {
    when(
      () => repository.importFromCsv(
        any(),
        any(),
        headerLine: any(named: 'headerLine'),
        locationOverride: any(named: 'locationOverride'),
      ),
    ).thenAnswer((_) async => 1);

    final params = ImportWinesFromCsvParams(
      csvContent: 'Nom\nVin1',
      mapping: const CsvColumnMapping(name: 1),
    );

    await useCase(params);

    final captured = verify(
      () => repository.importFromCsv(
        any(),
        any(),
        headerLine: any(named: 'headerLine'),
        locationOverride: captureAny(named: 'locationOverride'),
      ),
    ).captured;

    expect(captured.single, isNull);
  });

  test('retourne CacheFailure si le repository échoue', () async {
    when(
      () => repository.importFromCsv(
        any(),
        any(),
        headerLine: any(named: 'headerLine'),
        locationOverride: any(named: 'locationOverride'),
      ),
    ).thenThrow(Exception('db error'));

    final params = ImportWinesFromCsvParams(
      csvContent: 'Nom\nVin1',
      mapping: const CsvColumnMapping(name: 1),
    );

    final result = await useCase(params);

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<CacheFailure>()),
      (_) => fail('Doit retourner un Failure'),
    );
  });
}
