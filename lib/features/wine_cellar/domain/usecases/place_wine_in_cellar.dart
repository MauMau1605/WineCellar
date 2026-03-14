import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import '../repositories/virtual_cellar_repository.dart';

/// Parameters for placing one physical bottle in a virtual cellar slot.
class PlaceWineParams {
  final int wineId;
  final int cellarId;

  /// Column index (0-based).
  final int positionX;

  /// Row index (0-based).
  final int positionY;

  const PlaceWineParams({
    required this.wineId,
    required this.cellarId,
    required this.positionX,
    required this.positionY,
  });
}

class PlaceWineInCellarUseCase {
  final VirtualCellarRepository _repository;

  PlaceWineInCellarUseCase(this._repository);

  Future<Either<Failure, Unit>> call(PlaceWineParams params) {
    return _repository.placeWine(
      params.wineId,
      cellarId: params.cellarId,
      positionX: params.positionX,
      positionY: params.positionY,
    );
  }
}
