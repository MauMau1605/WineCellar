import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Add a new wine to the cellar.
///
/// Returns the generated wine ID on success.
class AddWineUseCase implements UseCase<int, WineEntity> {
  final WineRepository _repository;

  const AddWineUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(WineEntity wine) async {
    try {
      if (wine.name.trim().isEmpty) {
        return const Left(
          ValidationFailure('Le nom du vin est obligatoire.'),
        );
      }

      final id = await _repository.addWine(wine);
      return Right(id);
    } catch (e) {
      return Left(CacheFailure('Impossible d\'ajouter le vin.', cause: e));
    }
  }
}
