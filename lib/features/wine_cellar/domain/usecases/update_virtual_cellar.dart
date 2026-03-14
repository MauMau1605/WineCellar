import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import '../entities/virtual_cellar_entity.dart';
import '../repositories/virtual_cellar_repository.dart';

class UpdateVirtualCellarUseCase {
  final VirtualCellarRepository _repository;

  UpdateVirtualCellarUseCase(this._repository);

  Future<Either<Failure, Unit>> call(VirtualCellarEntity cellar) {
    return _repository.update(cellar);
  }
}
