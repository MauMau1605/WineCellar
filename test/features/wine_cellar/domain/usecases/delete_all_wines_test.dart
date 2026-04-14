import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/delete_all_wines.dart';

class _MockWineRepository extends Mock implements WineRepository {}

void main() {
  late _MockWineRepository repository;
  late DeleteAllWinesUseCase useCase;

  setUp(() {
    repository = _MockWineRepository();
    useCase = DeleteAllWinesUseCase(repository);
  });

  test('supprime tous les vins avec succès', () async {
    when(() => repository.deleteAllWines()).thenAnswer((_) async {});

    final result = await useCase(const NoParams());

    expect(result.isRight(), isTrue);
    verify(() => repository.deleteAllWines()).called(1);
  });

  test('retourne CacheFailure si le repository échoue', () async {
    when(() => repository.deleteAllWines())
        .thenThrow(Exception('database locked'));

    final result = await useCase(const NoParams());

    expect(result.isLeft(), isTrue);
    result.fold(
      (failure) {
        expect(failure, isA<CacheFailure>());
        expect(failure.message, 'Impossible de supprimer tous les vins.');
      },
      (_) => fail('Doit retourner un Failure'),
    );
  });
}
