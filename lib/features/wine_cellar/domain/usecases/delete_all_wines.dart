import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Delete all wines from the cellar (developer tool).
class DeleteAllWinesUseCase implements UseCase<void, NoParams> {
  final WineRepository _repository;

  const DeleteAllWinesUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    try {
      await _repository.deleteAllWines();
      return const Right(null);
    } catch (e) {
      return Left(
        CacheFailure('Impossible de supprimer tous les vins.', cause: e),
      );
    }
  }
}
