import 'package:fpdart/fpdart.dart';

import 'package:wine_cellar/core/errors/failures.dart';
import '../entities/virtual_cellar_entity.dart';
import '../repositories/virtual_cellar_repository.dart';

class CreateVirtualCellarUseCase {
  final VirtualCellarRepository _repository;

  CreateVirtualCellarUseCase(this._repository);

  Future<Either<Failure, int>> call(VirtualCellarEntity cellar) {
    return _repository.create(cellar);
  }
}
