import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Update an existing wine in the cellar.
class UpdateWineUseCase implements UseCase<void, WineEntity> {
  final WineRepository _repository;

  const UpdateWineUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(WineEntity wine) async {
    try {
      if (wine.id == null) {
        return const Left(
          ValidationFailure('Impossible de modifier un vin sans identifiant.'),
        );
      }
      if (wine.name.trim().isEmpty) {
        return const Left(
          ValidationFailure('Le nom du vin est obligatoire.'),
        );
      }

      await _repository.updateWine(wine);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Impossible de modifier le vin.', cause: e));
    }
  }
}
