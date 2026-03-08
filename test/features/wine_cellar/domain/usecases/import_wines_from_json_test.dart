import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_json.dart';

class _MockWineRepository extends Mock implements WineRepository {}

void main() {
  late _MockWineRepository repository;
  late ImportWinesFromJsonUseCase useCase;

  setUp(() {
    repository = _MockWineRepository();
    useCase = ImportWinesFromJsonUseCase(repository);
  });

  test('retourne ValidationFailure quand le contenu JSON est vide', () async {
    final result = await useCase('   ');

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<ValidationFailure>()),
      (_) => fail('Doit retourner un Failure'),
    );
  });

  test('retourne le nombre de vins importés en cas de succès', () async {
    when(() => repository.importFromJson(any())).thenAnswer((_) async => 4);

    final result = await useCase('{"wines": []}');

    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('Doit retourner un succès'),
      (count) => expect(count, 4),
    );
    verify(() => repository.importFromJson(any())).called(1);
  });

  test('retourne CacheFailure si le repository échoue', () async {
    when(() => repository.importFromJson(any())).thenThrow(Exception('boom'));

    final result = await useCase('{"wines": []}');

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) => expect(failure, isA<CacheFailure>()),
      (_) => fail('Doit retourner un Failure'),
    );
  });
}
