import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import '../repositories/virtual_cellar_repository.dart';

class GetWinePlacementsUseCase {
  final VirtualCellarRepository _repository;

  GetWinePlacementsUseCase(this._repository);

  Future<Either<Failure, List<BottlePlacementEntity>>> call(int wineId) {
    return _repository.getPlacementsByWineId(wineId);
  }
}
