import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Delete a wine from the cellar by its ID.
class DeleteWineUseCase implements UseCase<void, int> {
  final WineRepository _repository;

  const DeleteWineUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(int id) async {
    try {
      await _repository.deleteWine(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Impossible de supprimer le vin.', cause: e));
    }
  }
}
