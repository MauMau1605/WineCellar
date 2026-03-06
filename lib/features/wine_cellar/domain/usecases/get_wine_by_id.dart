import 'package:fpdart/fpdart.dart';
import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/repositories/wine_repository.dart';

/// Retrieve a single wine by its ID, including food pairings.
class GetWineByIdUseCase implements UseCase<WineEntity?, int> {
  final WineRepository _repository;

  const GetWineByIdUseCase(this._repository);

  @override
  Future<Either<Failure, WineEntity?>> call(int id) async {
    try {
      final wine = await _repository.getWineById(id);
      return Right(wine);
    } catch (e) {
      return Left(CacheFailure('Impossible de récupérer le vin.', cause: e));
    }
  }
}
