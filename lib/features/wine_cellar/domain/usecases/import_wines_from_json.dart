import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

class ImportWinesFromJsonUseCase implements UseCase<int, String> {
  final WineRepository _repository;

  const ImportWinesFromJsonUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(String jsonContent) async {
    try {
      if (jsonContent.trim().isEmpty) {
        return const Left(
          ValidationFailure('Le fichier JSON est vide.'),
        );
      }

      final count = await _repository.importFromJson(jsonContent);
      return Right(count);
    } catch (e) {
      return Left(CacheFailure('Échec de l\'import JSON.', cause: e));
    }
  }
}
