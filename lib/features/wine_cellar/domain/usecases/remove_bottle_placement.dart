import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import '../repositories/virtual_cellar_repository.dart';

class RemoveBottlePlacementUseCase {
  final VirtualCellarRepository _repository;

  RemoveBottlePlacementUseCase(this._repository);

  Future<Either<Failure, Unit>> call(int placementId) {
    return _repository.removePlacement(placementId);
  }
}
